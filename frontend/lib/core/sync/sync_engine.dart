import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../offline/offline_database.dart';
import '../providers/connectivity_provider.dart';

// ── Sync queue item ───────────────────────────────────────────────

class SyncItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;  // insert / update / delete
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
        id:         row['id'] as String,
        entityType: row['entity_type'] as String,
        entityId:   row['entity_id'] as String,
        operation:  row['operation'] as String,
        payload:    jsonDecode(row['payload'] as String)
            as Map<String, dynamic>,
        queuedAt:   row['queued_at'] as String,
        attempts:   row['attempts'] as int,
        lastError:  row['last_error'] as String?,
      );
}

// ── Offline queue helper ──────────────────────────────────────────

class OfflineQueue {
  final OfflineDatabase _db;
  OfflineQueue(this._db);

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    if (kIsWeb) return; // No offline queue on web
    final db = await _db.database;
    await db.insert('sync_queue', {
      'id':          const Uuid().v4(),
      'entity_type': entityType,
      'entity_id':   entityId,
      'operation':   operation,
      'payload':     jsonEncode(payload),
      'queued_at':   DateTime.now().toIso8601String(),
      'attempts':    0,
    });
  }

  Future<List<SyncItem>> pending() async {
    if (kIsWeb) return [];
    final db = await _db.database;
    final rows = await db.query(
      'sync_queue',
      where: 'attempts < 5',
      orderBy: 'queued_at ASC',
    );
    return rows.map(SyncItem.fromRow).toList();
  }

  Future<void> markDone(String id) async {
    final db = await _db.database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementAttempt(String id, String error) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1, last_error = ? WHERE id = ?',
      [error, id],
    );
  }
}

// ── Sync engine ───────────────────────────────────────────────────

class SyncEngine {
  final OfflineQueue _queue;
  final sb.SupabaseClient _client;

  SyncEngine(this._queue, this._client);

  bool _running = false;

  Future<void> syncAll() async {
    if (kIsWeb || _running) return;
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
      final table = item.entityType; // patients / visits / surgeries
      switch (item.operation) {
        case 'insert':
          await _client.from(table).upsert(item.payload);
        case 'update':
          await _client
              .from(table)
              .update(item.payload)
              .eq('id', item.entityId);
        case 'delete':
          await _client
              .from(table)
              .update({'is_active': false})
              .eq('id', item.entityId);
      }
      await _queue.markDone(item.id);
      debugPrint('[SyncEngine] synced ${item.entityType}/${item.entityId}');
    } catch (e) {
      await _queue.incrementAttempt(item.id, e.toString());
      debugPrint('[SyncEngine] failed ${item.entityType}/${item.entityId}: $e');
    }
  }
}

// ── Local cache helpers ───────────────────────────────────────────

class LocalPatientCache {
  final OfflineDatabase _db;
  LocalPatientCache(this._db);

  Future<void> upsert(Map<String, dynamic> patient) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.insert('patients', patient,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> search(String query) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    final q = '%$query%';
    return db.query(
      'patients',
      where: '(first_name LIKE ? OR last_name LIKE ? OR prn = ? OR phone LIKE ?)'
          ' AND is_active = 1',
      whereArgs: [q, q, query, q],
      orderBy: 'updated_at DESC',
      limit: 20,
    );
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    if (kIsWeb) return null;
    final db = await _db.database;
    final rows =
        await db.query('patients', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }
}

class LocalVisitCache {
  final OfflineDatabase _db;
  LocalVisitCache(this._db);

  Future<void> upsert(Map<String, dynamic> visit) async {
    if (kIsWeb) return;
    final db = await _db.database;
    await db.insert('visits', visit,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getForPatient(
      String patientId) async {
    if (kIsWeb) return [];
    final db = await _db.database;
    return db.query(
      'visits',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'visit_date DESC',
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────

final offlineDatabaseProvider =
    Provider<OfflineDatabase>((_) => OfflineDatabase());

final offlineQueueProvider = Provider<OfflineQueue>(
    (ref) => OfflineQueue(ref.watch(offlineDatabaseProvider)));

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(
      ref.watch(offlineQueueProvider),
      sb.Supabase.instance.client,
    ));

final localPatientCacheProvider = Provider<LocalPatientCache>(
    (ref) => LocalPatientCache(ref.watch(offlineDatabaseProvider)));

final localVisitCacheProvider = Provider<LocalVisitCache>(
    (ref) => LocalVisitCache(ref.watch(offlineDatabaseProvider)));

// ── Auto-sync on connectivity restore ────────────────────────────

class SyncCoordinator extends Notifier<void> {
  @override
  void build() {
    if (kIsWeb) return;
    ref.listen<bool?>(isOnlineProvider, (prev, isOnline) {
      if (isOnline == true && prev == false) {
        ref.read(syncEngineProvider).syncAll();
      }
    });
  }
}

final syncCoordinatorProvider =
    NotifierProvider<SyncCoordinator, void>(SyncCoordinator.new);
