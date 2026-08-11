import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';
import '../offline/offline_database.dart';
import '../offline/web_offline_store.dart';
import '../providers/connectivity_provider.dart';
import '../storage/storage_provider.dart';

// ── Sync queue item ───────────────────────────────────────────────

class SyncItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation; // insert / update / delete
  final Map<String, dynamic> payload;
  final String queuedAt;
  int attempts;
  String? lastError;

  SyncItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.queuedAt,
    this.attempts = 0,
    this.lastError,
  });

  factory SyncItem.fromRow(Map<String, dynamic> row) => SyncItem(
        id: row['id'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload:
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        queuedAt: row['queued_at'] as String,
        attempts: row['attempts'] as int,
        lastError: row['last_error'] as String?,
      );
}

// ── Offline queue helper ──────────────────────────────────────────

class OfflineQueue {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  OfflineQueue(this._db, {WebOfflineStore? webStore}) : _web = webStore;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) {
      await _web?.enqueue(
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
      );
      return;
    }
    final db = await _db.database;
    await db.insert('sync_queue', {
      'id': const Uuid().v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'queued_at': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
  }

  Future<List<SyncItem>> pending() async {
    if (kIsWeb) {
      return (_web?.pending() ?? []).map(SyncItem.fromRow).toList();
    }
    final db = await _db.database;
    // No attempts filter — all queued items are returned so the retry loop
    // never terminates and the pending count is always accurate.
    final rows = await db.query(
      'sync_queue',
      orderBy: 'queued_at ASC',
    );
    return rows.map(SyncItem.fromRow).toList();
  }

  // Resets the attempt counter for ALL failed items so they get a fresh retry
  // when syncAll() runs next. Called at app startup / reconnect so items that
  // exhausted their retries due to a transient error (e.g. UUID patientId) are
  // not abandoned forever.
  Future<void> resetAllFailed() async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('sync_queue', {'attempts': 0}, where: 'attempts >= 5');
  }

  Future<void> markDone(String id) async {
    if (kIsWeb) {
      await _web?.markDone(id);
      return;
    }
    final db = await _db.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementAttempt(String id, String error) async {
    if (kIsWeb) {
      await _web?.incrementAttempt(id, error);
      return;
    }
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }

  // When the backend assigns a new ID to a patient, update all queued visit/surgery
  // payloads that referenced the old patient UUID so the SyncEngine posts to the
  // correct /patients/{newId}/... path on its next attempt.
  Future<void> remapPatientIdInQueue(
      String oldPatientId, String newPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final rows = await db.query('sync_queue',
        where: 'entity_type IN (?, ?)', whereArgs: ['visits', 'surgeries']);
    for (final row in rows) {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      bool changed = false;
      if (payload['patientId'] == oldPatientId) {
        payload['patientId'] = newPatientId;
        changed = true;
      }
      if (payload['patient_id'] == oldPatientId) {
        payload['patient_id'] = newPatientId;
        changed = true;
      }
      if (changed) {
        // Reset attempts so the item gets a clean retry with the correct patientId.
        await db.update('sync_queue',
            {'payload': jsonEncode(payload), 'attempts': 0},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
}

// ── Visit sync event (notifies visitsProvider to reload after SyncEngine syncs) ─

/// Incremented each time SyncEngine successfully syncs a visit.
/// visitsProvider listens to this and reloads from SQLite so the grey dot
/// turns green without the user needing to navigate away.
final visitSyncEventProvider = StateProvider<int>((ref) => 0);

/// Emits (count, timestamp) after a sync run that pushed ≥1 item to the server.
/// UI listens to this to show a "X records synced" success message.
final syncSuccessProvider =
    StateProvider<({int count, DateTime at})?>((_) => null);

// ── Sync engine (push: local → API) ──────────────────────────────

class SyncEngine {
  final OfflineQueue _queue;
  final ApiClient _api;
  final LocalVisitCache _localVisit;
  final LocalSurgeryCache _localSurgery;
  final LocalPhotoStore _localPhoto;
  final LocalPrescriptionCache _localPrescription;
  final PatientIdMap _idMap;
  final Ref _ref;

  SyncEngine(this._queue, this._api, this._localVisit, this._localSurgery,
      this._localPhoto, this._localPrescription, this._idMap, this._ref);

  bool _running = false;

  Future<int> syncAll() async {
    if (_running) return 0;
    _running = true;
    int syncedCount = 0;
    try {
      // Give items that exhausted retries a fresh chance — they may have been
      // stuck due to a UUID patientId that is now resolved, or a transient
      // network failure (e.g. Render cold start). Runs once per session.
      await _queue.resetAllFailed();

      // Process items one at a time, reloading the queue after any patient-ID
      // remap so subsequent visit/surgery items use the updated numeric patientId.
      List<SyncItem> items = await _queue.pending();
      int i = 0;
      while (i < items.length) {
        final result = await _processItem(items[i]);
        if (result.success) syncedCount++;
        if (result.remapped) {
          // Queue payloads were rewritten — reload to pick up new patientIds.
          items = await _queue.pending();
          i = 0;
        } else {
          i++;
        }
      }
    } finally {
      _running = false;
    }

    // Reset any items that accumulated high attempt counts during this run
    // (upgrade compat: old installs may have items stuck at attempts ≥ 5).
    await _queue.resetAllFailed();

    // If items remain (e.g. transient failure or Render cold-start timeout),
    // schedule one automatic retry after 60 s so the user doesn't have to
    // toggle airplane mode or restart the app.
    final remaining = await _queue.pending();
    if (remaining.isNotEmpty) {
      Future.delayed(const Duration(seconds: 60), syncAll);
    }
    return syncedCount;
  }

  // Returns (remapped: true) when patient IDs were rewritten (caller reloads queue).
  // Returns (success: true) when the item was pushed to the server successfully.
  Future<({bool remapped, bool success})> _processItem(SyncItem item) async {
    try {
      // Resolve a UUID patientId to a numeric one via the id map if possible.
      // This covers offline-created visits whose patient already synced outside
      // the SyncEngine (e.g., via patient_provider._syncPatientToApi).
      final payload = await _resolveUuidPatientId(item.payload);
      final path = _buildPath(item, payload: payload);
      bool remapped = false;
      switch (item.operation) {
        case 'insert':
          if (item.entityType == 'patients') {
            // Parse response to get server-assigned numeric ID, then remap all
            // queued visits/surgeries that referenced this patient's client UUID.
            // Backend wraps all responses in ApiResponse.data, so use body['data'].
            final raw = await _api.post<dynamic>(path, data: payload);
            final dataMap = _extractData(raw);
            final newId = dataMap?['id']?.toString();
            if (newId != null && newId != item.entityId) {
              await _idMap.insert(item.entityId, newId);
              await _localVisit.remapPatientId(item.entityId, newId);
              await _localSurgery.remapPatientId(item.entityId, newId);
              await _localPhoto.remapPatientId(item.entityId, newId);
              await _localPrescription.remapPatientId(item.entityId, newId);
              await _queue.remapPatientIdInQueue(item.entityId, newId);
              remapped = true;
            }
          } else if (item.entityType == 'visits') {
            // Parse response to get server visit ID, then replace the local
            // UUID visit row with the server-confirmed entry.
            final raw = await _api.post<dynamic>(path, data: payload);
            final dataMap = _extractData(raw);
            if (dataMap == null) throw Exception('empty visit response');
            final newVisitId = dataMap['id']?.toString();
            if (newVisitId != null && newVisitId != item.entityId) {
              await _localVisit.remapVisitId(item.entityId, newVisitId);
              await _localVisit.purge(item.entityId);
            }
            await _localVisit.upsert(dataMap);
            // Signal visitsProvider to reload from SQLite so the UI updates
            // immediately (grey dot → green) without user needing to navigate.
            _ref.read(visitSyncEventProvider.notifier).state++;
          } else {
            await _api.post<void>(path, data: payload);
          }
        case 'update':
          await _api.put<void>(path, data: payload);
        case 'delete':
          await _api.delete<void>(path);
      }
      await _queue.markDone(item.id);
      debugPrint('[SyncEngine] synced ${item.entityType}/${item.entityId}');
      return (remapped: remapped, success: true);
    } catch (e) {
      await _queue.incrementAttempt(item.id, e.toString());
      debugPrint('[SyncEngine] failed ${item.entityType}/${item.entityId}: $e');
      return (remapped: false, success: false);
    }
  }

  // Safely extract body['data'] from the backend's ApiResponse envelope.
  // Works regardless of whether Dio parsed the JSON as Map<String, dynamic>
  // or Map<dynamic, dynamic> — avoids runtime type-cast errors.
  Map<String, dynamic>? _extractData(dynamic raw) {
    if (raw is! Map) return null;
    final d = raw['data'];
    if (d is! Map) return null;
    return d.map((k, v) => MapEntry(k.toString(), v));
  }

  // If the payload's patientId is a client UUID that's now in the id map,
  // return a copy of the payload with the numeric server ID substituted.
  Future<Map<String, dynamic>> _resolveUuidPatientId(
      Map<String, dynamic> payload) async {
    final pid =
        (payload['patientId'] ?? payload['patient_id']) as Object?;
    if (pid == null) return payload;
    final pidStr = pid.toString();
    if (RegExp(r'^\d+$').hasMatch(pidStr)) return payload; // already numeric
    final resolved = await _idMap.resolve(pidStr);
    if (resolved == pidStr) return payload; // no mapping found
    final updated = Map<String, dynamic>.from(payload);
    if (payload.containsKey('patientId')) updated['patientId'] = resolved;
    if (payload.containsKey('patient_id')) updated['patient_id'] = resolved;
    return updated;
  }

  String _buildPath(SyncItem item, {Map<String, dynamic>? payload}) {
    final id = item.entityId;
    final p = payload ?? item.payload;
    final patientId = p['patientId'] ?? p['patient_id'];
    switch (item.entityType) {
      case 'patients':
        return item.operation == 'insert' ? '/patients' : '/patients/$id';
      case 'visits':
        return item.operation == 'insert'
            ? '/patients/$patientId/visits'
            : '/patients/$patientId/visits/$id';
      case 'surgeries':
        return item.operation == 'insert'
            ? '/patients/$patientId/surgeries'
            : '/patients/$patientId/surgeries/$id';
      case 'examinations':
        return '/patients/$patientId/visits/${p['visitId']}/examination';
      case 'prescriptions':
        final rxId = p['id'];
        return rxId != null && (rxId as String).isNotEmpty
            ? '/prescriptions/$rxId'
            : '/patients/$patientId/visits/${p['visitId']}/prescriptions';
      default:
        return '/${item.entityType}/$id';
    }
  }
}

// ── Local patient cache ───────────────────────────────────────────

class LocalPatientCache {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  LocalPatientCache(this._db, {WebOfflineStore? webStore}) : _web = webStore;

  Future<void> upsert(Map<String, dynamic> apiJson) async {
    if (kIsWeb) {
      await _web?.upsertPatient(apiJson);
      return;
    }
    final db = await _db.database;
    final id = (apiJson['id'] as Object).toString();
    final now = DateTime.now().toIso8601String();
    await db.insert(
        'patients',
        {
          'id': id,
          'prn': apiJson['prn'] ?? '',
          'first_name': apiJson['firstName'] ?? apiJson['first_name'] ?? '',
          'last_name': apiJson['lastName'] ?? apiJson['last_name'] ?? '',
          'age': apiJson['age'],
          'date_of_birth':
              apiJson['dateOfBirth'] ?? apiJson['date_of_birth'],
          'sex': apiJson['sex'],
          'phone': apiJson['phone'],
          'address': apiJson['address'],
          'notes': apiJson['notes'],
          'data_json': jsonEncode(apiJson),
          'sync_status': apiJson['syncStatus'] ?? apiJson['sync_status'] ?? 'synced',
          'is_active': apiJson['isActive'] == false ? 0 : 1,
          'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
          'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
          'created_by': apiJson['createdBy'] ?? apiJson['created_by'],
          'updated_by': apiJson['updatedBy'] ?? apiJson['updated_by'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAll({String? search}) async {
    if (kIsWeb) return _web?.getAllPatients(search: search) ?? [];
    final db = await _db.database;
    if (search != null && search.isNotEmpty) {
      final q = '%$search%';
      return db.query(
        'patients',
        where:
            '(first_name LIKE ? OR last_name LIKE ? OR prn LIKE ? OR phone LIKE ?)'
            ' AND is_active = 1',
        whereArgs: [q, q, q, q],
        orderBy: 'updated_at DESC',
        limit: 100,
      );
    }
    return db.query('patients',
        where: 'is_active = 1', orderBy: 'updated_at DESC', limit: 100);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    if (kIsWeb) return _web?.getPatient(id);
    final db = await _db.database;
    final rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markPending(String id) async {
    if (kIsWeb) return; // No-op on web; handled by sync queue state
    final db = await _db.database;
    await db.update('patients', {'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    if (kIsWeb) {
      await _web?.deletePatient(id);
      return;
    }
    final db = await _db.database;
    await db.update('patients', {'is_active': 0, 'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  // Hard-delete a temp local entry (e.g., client UUID after server returned a different ID).
  Future<void> purge(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.delete('patients', where: 'id = ?', whereArgs: [id]);
  }
}

// ── Local visit cache ─────────────────────────────────────────────

class LocalVisitCache {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  LocalVisitCache(this._db, {WebOfflineStore? webStore}) : _web = webStore;

  Future<void> upsert(Map<String, dynamic> apiJson) async {
    if (kIsWeb) {
      await _web?.upsertVisit(apiJson);
      return;
    }
    final db = await _db.database;
    // 'clientId' is the API key; 'id' is added by toFullJson() for local use.
    final id = ((apiJson['id'] ?? apiJson['clientId']) as Object).toString();
    final now = DateTime.now().toIso8601String();
    await db.insert(
        'visits',
        {
          'id': id,
          'patient_id':
              (apiJson['patientId'] ?? apiJson['patient_id'] as Object)
                  .toString(),
          'visit_date': apiJson['visitDate'] ?? apiJson['visit_date'] ?? now,
          'visit_type': apiJson['visitType'] ?? apiJson['visit_type'] ?? 'opd',
          'complaints': apiJson['complaints'],
          'examination': apiJson['examination'],
          'clinical_impression':
              apiJson['clinicalImpression'] ?? apiJson['clinical_impression'],
          'plan': apiJson['plan'],
          'notes': apiJson['notes'],
          'status': apiJson['status'] ?? 'draft',
          'data_json': jsonEncode(apiJson),
          'sync_status': apiJson['syncStatus'] ?? apiJson['sync_status'] ?? 'synced',
          'is_active': apiJson['isActive'] == false ? 0 : 1,
          'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
          'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
          'created_by': apiJson['createdBy'] ?? apiJson['created_by'],
          'updated_by': apiJson['updatedBy'] ?? apiJson['updated_by'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getForPatient(
      String patientId) async {
    if (kIsWeb) return _web?.getVisitsForPatient(patientId) ?? [];
    final db = await _db.database;
    return db.query(
      'visits',
      where: 'patient_id = ? AND is_active = 1',
      whereArgs: [patientId],
      orderBy: 'visit_date DESC',
    );
  }

  // Hard-delete a temp local entry (e.g., client UUID after server returned a different ID).
  Future<void> purge(String id) async {
    if (kIsWeb) {
      await _web?.deleteVisit(id);
      return;
    }
    final db = await _db.database;
    await db.delete('visits', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    if (kIsWeb) return _web?.getVisit(id);
    final db = await _db.database;
    final rows =
        await db.query('visits', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markPending(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('visits', {'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  // Mark as synced BEFORE purging so _syncFromApi won't treat the UUID as
  // a still-pending local entry during the brief window before purge runs.
  Future<void> markSynced(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('visits', {'sync_status': 'synced'},
        where: 'id = ?', whereArgs: [id]);
  }

  // Returns visits for a patient that are still pending in SQLite.
  // Used by _syncFromApi to find genuinely unsynced local entries without
  // relying on in-memory state (which can be stale / cause duplicates).
  Future<List<Map<String, dynamic>>> getPendingForPatient(
      String patientId) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    return db.query(
      'visits',
      where: 'patient_id = ? AND is_active = 1 AND sync_status = ?',
      whereArgs: [patientId, 'pending'],
    );
  }

  Future<void> delete(String id) async {
    if (kIsWeb) {
      await _web?.deleteVisit(id);
      return;
    }
    final db = await _db.database;
    await db.update('visits', {'is_active': 0, 'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  // Called at load time for numeric patient IDs: finds any visits still stored
  // under an old client UUID that maps to this server ID, remaps them, and
  // updates their data_json.  Handles the race where patient sync completed
  // before the OPD visit was created in the registration wizard.
  Future<void> remapFromIdMap(String numericPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final mapped = await db.query('patient_id_map',
        where: 'server_id = ?', whereArgs: [numericPatientId]);
    for (final m in mapped) {
      final clientId = m['client_id'] as String;
      await remapPatientId(clientId, numericPatientId);
    }
  }

  // When the backend assigns a new numeric ID to a patient, update all local
  // visits that referenced the old client UUID so they can be found by the
  // new server-assigned ID on subsequent loads.
  Future<void> remapPatientId(
      String oldPatientId, String newPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final rows = await db.query('visits',
        where: 'patient_id = ?', whereArgs: [oldPatientId]);
    for (final row in rows) {
      final updates = <String, Object?>{'patient_id': newPatientId};
      final js = row['data_json'] as String?;
      if (js != null) {
        try {
          final decoded = jsonDecode(js) as Map<String, dynamic>;
          decoded['patientId'] = newPatientId;
          updates['data_json'] = jsonEncode(decoded);
        } catch (_) {}
      }
      await db.update('visits', updates,
          where: 'id = ?', whereArgs: [row['id']]);
    }
  }

  // Fallback repair: scans ALL visits with a UUID patient_id (non-numeric)
  // and remaps any that were created within 24 h of [numericPatientId].
  // Used in _loadLocal when no visits are found and remapFromIdMap also finds
  // nothing — covers patients created before the patient_id_map table existed.
  Future<void> repairOrphanedVisitsForPatient(String numericPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    // Get this patient's creation time.
    final patRows = await db.query('patients',
        columns: ['created_at'], where: 'id = ? AND is_active = 1',
        whereArgs: [numericPatientId]);
    if (patRows.isEmpty) return;
    final patCreatedStr = patRows.first['created_at'] as String?;
    if (patCreatedStr == null) return;
    DateTime patTime;
    try { patTime = DateTime.parse(patCreatedStr).toUtc(); } catch (_) { return; }

    // Find active visits whose patient_id looks like a UUID (non-numeric).
    final orphans = await db.rawQuery('''
      SELECT id, patient_id, created_at, data_json FROM visits
      WHERE is_active = 1
        AND patient_id NOT IN (SELECT id FROM patients WHERE is_active = 1)
        AND patient_id GLOB '*-*'
    ''');
    for (final row in orphans) {
      final visitCreatedStr = row['created_at'] as String?;
      if (visitCreatedStr == null) continue;
      DateTime visitTime;
      try { visitTime = DateTime.parse(visitCreatedStr).toUtc(); } catch (_) { continue; }
      final diffSec = (visitTime.millisecondsSinceEpoch -
              patTime.millisecondsSinceEpoch).abs() ~/ 1000;
      if (diffSec > 86400) continue; // outside 24-h window

      final visitId = row['id'] as String;
      final oldPid  = row['patient_id'] as String;
      final updates = <String, Object?>{'patient_id': numericPatientId};
      final js = row['data_json'] as String?;
      if (js != null) {
        try {
          final decoded = jsonDecode(js) as Map<String, dynamic>;
          decoded['patientId'] = numericPatientId;
          updates['data_json'] = jsonEncode(decoded);
        } catch (_) {}
      }
      await db.update('visits', updates, where: 'id = ?', whereArgs: [visitId]);
      // Cache the mapping so this repair is not needed again.
      try {
        await db.insert('patient_id_map',
            {'client_id': oldPid, 'server_id': numericPatientId},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      } catch (_) {}
    }
  }

  // When the backend assigns a new numeric ID to a visit (UUID → numeric),
  // remap all prescriptions, examinations, and photos so they remain linked.
  Future<void> remapVisitId(String oldVisitId, String newVisitId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('prescriptions', {'visit_id': newVisitId},
        where: 'visit_id = ?', whereArgs: [oldVisitId]);
    await db.update('examinations', {'visit_id': newVisitId},
        where: 'visit_id = ?', whereArgs: [oldVisitId]);
    await db.update('photos', {'visit_id': newVisitId},
        where: 'visit_id = ?', whereArgs: [oldVisitId]);
  }
}

// ── Local surgery cache ───────────────────────────────────────────

class LocalSurgeryCache {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  LocalSurgeryCache(this._db, {WebOfflineStore? webStore}) : _web = webStore;

  Future<void> upsert(Map<String, dynamic> apiJson) async {
    if (kIsWeb) {
      await _web?.upsertSurgery(apiJson);
      return;
    }
    final db = await _db.database;
    final id = (apiJson['id'] as Object).toString();
    final now = DateTime.now().toIso8601String();
    await db.insert(
        'surgeries',
        {
          'id': id,
          'patient_id':
              (apiJson['patientId'] ?? apiJson['patient_id'] as Object)
                  .toString(),
          'surgery_date':
              apiJson['surgeryDate'] ?? apiJson['surgery_date'] ?? now,
          'your_role': apiJson['yourRole'] ?? apiJson['your_role'],
          'pre_op_diagnosis':
              apiJson['preOpDiagnosis'] ?? apiJson['pre_op_diagnosis'],
          'procedure': apiJson['procedure'],
          'primary_surgeon':
              apiJson['primarySurgeon'] ?? apiJson['primary_surgeon'],
          'assistant_surgeons':
              apiJson['assistantSurgeons'] ?? apiJson['assistant_surgeons'],
          'anesthesia_type':
              apiJson['anesthesiaType'] ?? apiJson['anesthesia_type'],
          'anesthesiologist': apiJson['anesthesiologist'],
          'implants': apiJson['implants'],
          'intraop_findings':
              apiJson['intraopFindings'] ?? apiJson['intraop_findings'],
          'ot_notes': apiJson['otNotes'] ?? apiJson['ot_notes'],
          'complications': apiJson['complications'],
          'post_op_plan': apiJson['postOpPlan'] ?? apiJson['post_op_plan'],
          'status': apiJson['status'] ?? 'draft',
          'data_json': jsonEncode(apiJson),
          'sync_status': apiJson['syncStatus'] ?? apiJson['sync_status'] ?? 'synced',
          'is_active': apiJson['isActive'] == false ? 0 : 1,
          'created_at': apiJson['createdAt'] ?? apiJson['created_at'] ?? now,
          'updated_at': apiJson['updatedAt'] ?? apiJson['updated_at'] ?? now,
          'created_by': apiJson['createdBy'] ?? apiJson['created_by'],
          'updated_by': apiJson['updatedBy'] ?? apiJson['updated_by'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getForPatient(
      String patientId) async {
    if (kIsWeb) return _web?.getSurgeriesForPatient(patientId) ?? [];
    final db = await _db.database;
    return db.query(
      'surgeries',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'surgery_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    if (kIsWeb) return _web?.getSurgery(id);
    final db = await _db.database;
    final rows =
        await db.query('surgeries', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> markPending(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('surgeries', {'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    if (kIsWeb) {
      await _web?.deleteSurgery(id);
      return;
    }
    final db = await _db.database;
    await db.update('surgeries', {'is_active': 0, 'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remapPatientId(
      String oldPatientId, String newPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final rows = await db.query('surgeries',
        where: 'patient_id = ?', whereArgs: [oldPatientId]);
    for (final row in rows) {
      final updates = <String, Object?>{'patient_id': newPatientId};
      final js = row['data_json'] as String?;
      if (js != null) {
        try {
          final decoded = jsonDecode(js) as Map<String, dynamic>;
          decoded['patientId'] = newPatientId;
          updates['data_json'] = jsonEncode(decoded);
        } catch (_) {}
      }
      await db.update('surgeries', updates,
          where: 'id = ?', whereArgs: [row['id']]);
    }
  }
}

// ── Local examination cache ───────────────────────────────────────

class LocalExaminationCache {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  LocalExaminationCache(this._db, {WebOfflineStore? webStore})
      : _web = webStore;

  Future<void> upsert(
      String visitId, String patientId, Map<String, dynamic> apiJson) async {
    if (kIsWeb) {
      await _web?.upsertExamination(visitId, patientId, apiJson);
      return;
    }
    final db = await _db.database;
    await db.insert(
        'examinations',
        {
          'visit_id': visitId,
          'patient_id': patientId,
          'data_json': jsonEncode(apiJson),
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getForVisit(String visitId) async {
    if (kIsWeb) return _web?.getExamination(visitId);
    final db = await _db.database;
    final rows = await db
        .query('examinations', where: 'visit_id = ?', whereArgs: [visitId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final json =
        jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
    return json;
  }

  Future<void> markPending(String visitId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('examinations', {'sync_status': 'pending'},
        where: 'visit_id = ?', whereArgs: [visitId]);
  }
}

// ── Local prescription cache ──────────────────────────────────────

class LocalPrescriptionCache {
  final OfflineDatabase _db;
  final WebOfflineStore? _web;

  LocalPrescriptionCache(this._db, {WebOfflineStore? webStore})
      : _web = webStore;

  Future<void> upsert(
      String visitId, String patientId, Map<String, dynamic> apiJson) async {
    if (kIsWeb) {
      await _web?.upsertPrescription(visitId, patientId, apiJson);
      return;
    }
    final db = await _db.database;
    await db.insert(
        'prescriptions',
        {
          'visit_id': visitId,
          'patient_id': patientId,
          'data_json': jsonEncode(apiJson),
          'sync_status': 'synced',
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getForVisit(String visitId) async {
    if (kIsWeb) return _web?.getPrescription(visitId);
    final db = await _db.database;
    final rows = await db.query('prescriptions',
        where: 'visit_id = ?', whereArgs: [visitId]);
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['data_json'] as String)
        as Map<String, dynamic>;
  }

  Future<void> markPending(String visitId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('prescriptions', {'sync_status': 'pending'},
        where: 'visit_id = ?', whereArgs: [visitId]);
  }

  Future<void> remapPatientId(String oldPatientId, String newPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('prescriptions', {'patient_id': newPatientId},
        where: 'patient_id = ?', whereArgs: [oldPatientId]);
  }

  Future<List<Map<String, dynamic>>> getAllForPatient(String patientId) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    final rows = await db.query('prescriptions',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'updated_at DESC');
    return rows.map((r) => {
      ...jsonDecode(r['data_json'] as String) as Map<String, dynamic>,
      '_visitId': r['visit_id'],
      '_updatedAt': r['updated_at'],
    }).toList();
  }
}

// ── Local photo store ─────────────────────────────────────────────

class LocalPhotoStore {
  final OfflineDatabase _db;
  LocalPhotoStore(this._db);

  Future<void> insert(Map<String, dynamic> row) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.insert('photos', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getForPatient(String patientId) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    return db.query('photos',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'created_at DESC');
  }

  Future<List<Map<String, dynamic>>> getPendingForPatient(
      String patientId) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    return db.query('photos',
        where: 'patient_id = ? AND is_uploaded = 0',
        whereArgs: [patientId],
        orderBy: 'created_at ASC');
  }

  Future<List<Map<String, dynamic>>> getAllPending() async {
    if (kIsWeb) return [];
    final db = await _db.database;
    return db.query('photos',
        where: 'is_uploaded = 0', orderBy: 'created_at ASC');
  }

  Future<void> markUploaded(String id, String url, String storagePath) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update(
      'photos',
      {'is_uploaded': 1, 'url': url, 'storage_path': storagePath, 'local_path': null},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.delete('photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remapPatientId(
      String oldPatientId, String newPatientId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.update('photos', {'patient_id': newPatientId},
        where: 'patient_id = ?', whereArgs: [oldPatientId]);
  }
}

// ── Local drugs cache ─────────────────────────────────────────────

class LocalDrugCache {
  final OfflineDatabase _db;
  LocalDrugCache(this._db);

  Future<void> upsertAll(List<Map<String, dynamic>> drugs) async {
    if (kIsWeb) return;
    final db = await _db.database;
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    for (final d in drugs) {
      batch.insert(
          'drugs_cache',
          {
            'id': (d['id'] as Object).toString(),
            'data_json': jsonEncode(d),
            'cached_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    if (kIsWeb) return [];
    final db = await _db.database;
    final rows = await db.query('drugs_cache', orderBy: 'id');
    return rows
        .map((r) =>
            jsonDecode(r['data_json'] as String) as Map<String, dynamic>)
        .toList();
  }

  Future<bool> hasCache() async {
    if (kIsWeb) return false;
    final db = await _db.database;
    final count =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM drugs_cache'));
    return (count ?? 0) > 0;
  }

  Future<void> clearAll() async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.delete('drugs_cache');
  }
}

// ── Patient ID map (client UUID → server-assigned numeric ID) ────

class PatientIdMap {
  final OfflineDatabase _db;
  PatientIdMap(this._db);

  Future<void> insert(String clientId, String serverId) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.insert(
      'patient_id_map',
      {'client_id': clientId, 'server_id': serverId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Returns the server-assigned ID if one was recorded for this clientId,
  // otherwise returns the input unchanged.
  Future<String> resolve(String id) async {
    if (kIsWeb) return id;
    final db = await _db.database;
    final rows = await db.query('patient_id_map',
        where: 'client_id = ?', whereArgs: [id]);
    return rows.isEmpty ? id : rows.first['server_id'] as String;
  }
}

// ── Providers ─────────────────────────────────────────────────────

final offlineDatabaseProvider =
    Provider<OfflineDatabase>((_) => OfflineDatabase());

final webOfflineStoreProvider = Provider<WebOfflineStore?>((ref) {
  if (!kIsWeb) return null;
  return WebOfflineStore(ref.watch(sharedPreferencesProvider));
});

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      ref.watch(offlineQueueProvider),
      ref.watch(apiClientProvider),
      ref.watch(localVisitCacheProvider),
      ref.watch(localSurgeryCacheProvider),
      ref.watch(localPhotoStoreProvider),
      ref.watch(localPrescriptionCacheProvider),
      ref.watch(patientIdMapProvider),
      ref,
    ));

final localPatientCacheProvider = Provider<LocalPatientCache>((ref) =>
    LocalPatientCache(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final localVisitCacheProvider = Provider<LocalVisitCache>((ref) =>
    LocalVisitCache(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final localSurgeryCacheProvider = Provider<LocalSurgeryCache>((ref) =>
    LocalSurgeryCache(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final localExaminationCacheProvider = Provider<LocalExaminationCache>((ref) =>
    LocalExaminationCache(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final localPrescriptionCacheProvider = Provider<LocalPrescriptionCache>((ref) =>
    LocalPrescriptionCache(
      ref.watch(offlineDatabaseProvider),
      webStore: ref.watch(webOfflineStoreProvider),
    ));

final localDrugCacheProvider = Provider<LocalDrugCache>(
    (ref) => LocalDrugCache(ref.watch(offlineDatabaseProvider)));

final localPhotoStoreProvider = Provider<LocalPhotoStore>(
    (ref) => LocalPhotoStore(ref.watch(offlineDatabaseProvider)));

final patientIdMapProvider = Provider<PatientIdMap>(
    (ref) => PatientIdMap(ref.watch(offlineDatabaseProvider)));

// ── Auto-sync on connectivity restore ────────────────────────────

class SyncCoordinator extends Notifier<void> {
  @override
  void build() {
    // Flush pending queue on startup if already online (covers stuck items
    // from previous sessions that never got a connectivity-change event).
    Future.microtask(() async {
      if (ref.read(isOnlineProvider) == true) {
        final count = await ref.read(syncEngineProvider).syncAll();
        if (count > 0) {
          ref.read(syncSuccessProvider.notifier).state =
              (count: count, at: DateTime.now());
        }
      }
    });

    ref.listen<bool?>(isOnlineProvider, (prev, isOnline) {
      if (isOnline == true && prev == false) {
        Future(() async {
          final count = await ref.read(syncEngineProvider).syncAll();
          if (count > 0) {
            ref.read(syncSuccessProvider.notifier).state =
                (count: count, at: DateTime.now());
          }
        });
      }
    });
  }
}

final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinator, void>(SyncCoordinator.new);
