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
    final rows = await db.query(
      'sync_queue',
      where: 'attempts < 5',
      orderBy: 'queued_at ASC',
    );
    return rows.map(SyncItem.fromRow).toList();
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
        await db.update('sync_queue', {'payload': jsonEncode(payload)},
            where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }
}

// ── Sync engine (push: local → API) ──────────────────────────────

class SyncEngine {
  final OfflineQueue _queue;
  final ApiClient _api;

  SyncEngine(this._queue, this._api);

  bool _running = false;

  Future<void> syncAll() async {
    if (_running) return;
    _running = true;
    try {
      final items = await _queue.pending();
      for (final item in items) {
        await _processItem(item);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _processItem(SyncItem item) async {
    try {
      final path = _buildPath(item);
      switch (item.operation) {
        case 'insert':
          await _api.post<void>(path, data: item.payload);
        case 'update':
          await _api.put<void>(path, data: item.payload);
        case 'delete':
          await _api.delete<void>(path);
      }
      await _queue.markDone(item.id);
      debugPrint('[SyncEngine] synced ${item.entityType}/${item.entityId}');
    } catch (e) {
      await _queue.incrementAttempt(item.id, e.toString());
      debugPrint(
          '[SyncEngine] failed ${item.entityType}/${item.entityId}: $e');
    }
  }

  String _buildPath(SyncItem item) {
    final id = item.entityId;
    final patientId =
        item.payload['patientId'] ?? item.payload['patient_id'];
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
        return '/patients/$patientId/visits/${item.payload['visitId']}/examination';
      case 'prescriptions':
        final rxId = item.payload['id'];
        return rxId != null && (rxId as String).isNotEmpty
            ? '/prescriptions/$rxId'
            : '/patients/$patientId/visits/${item.payload['visitId']}/prescriptions';
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

  Future<void> delete(String id) async {
    if (kIsWeb) {
      await _web?.deleteVisit(id);
      return;
    }
    final db = await _db.database;
    await db.update('visits', {'is_active': 0, 'sync_status': 'pending'},
        where: 'id = ?', whereArgs: [id]);
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
    ref.listen<bool?>(isOnlineProvider, (prev, isOnline) {
      if (isOnline == true && prev == false) {
        ref.read(syncEngineProvider).syncAll();
      }
    });
  }
}

final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinator, void>(SyncCoordinator.new);
