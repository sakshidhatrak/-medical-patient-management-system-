import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/error/exceptions.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class SyncQueueItem {
  final String id;
  final String entityType;
  final String entityId;
  final String operation; // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final String queuedAt;
  final int attempts;

  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.queuedAt,
    required this.attempts,
  });

  factory SyncQueueItem.fromSqlite(Map<String, dynamic> row) => SyncQueueItem(
        id: row['id'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        queuedAt: row['queued_at'] as String,
        attempts: row['attempts'] as int,
      );

  Map<String, dynamic> toSqlite() => {
        'id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'queued_at': queuedAt,
        'attempts': attempts,
      };
}

// ── Interface ─────────────────────────────────────────────────────────────────

abstract interface class SyncQueueLocalDataSource {
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  });

  Future<List<SyncQueueItem>> getAll();

  Future<void> remove(String id);

  Future<void> clearCompleted(List<String> ids);

  Future<void> incrementAttempts(String id);
}

// ── Implementation ────────────────────────────────────────────────────────────

class SyncQueueLocalDataSourceImpl implements SyncQueueLocalDataSource {
  final DatabaseHelper _dbHelper;
  final _uuid = const Uuid();

  SyncQueueLocalDataSourceImpl(this._dbHelper);

  static const String _table = 'sync_queue';

  @override
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final db = await _dbHelper.database;
      final item = SyncQueueItem(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        payload: payload,
        queuedAt: DateTime.now().toIso8601String(),
        attempts: 0,
      );
      await db.insert(_table, item.toSqlite());
    } catch (e) {
      throw CacheException('Failed to enqueue sync item.', code: 'DB_WRITE');
    }
  }

  @override
  Future<List<SyncQueueItem>> getAll() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(_table, orderBy: 'queued_at ASC');
      return rows.map(SyncQueueItem.fromSqlite).toList();
    } catch (e) {
      throw CacheException('Failed to fetch sync queue.', code: 'DB_READ');
    }
  }

  @override
  Future<void> remove(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw CacheException('Failed to remove sync queue item.', code: 'DB_DELETE');
    }
  }

  @override
  Future<void> clearCompleted(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final db = await _dbHelper.database;
      final placeholders = List.filled(ids.length, '?').join(', ');
      await db.delete(
        _table,
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    } catch (e) {
      throw CacheException('Failed to clear sync queue items.', code: 'DB_DELETE');
    }
  }

  @override
  Future<void> incrementAttempts(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.rawUpdate(
        'UPDATE $_table SET attempts = attempts + 1 WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw CacheException('Failed to increment sync attempts.', code: 'DB_WRITE');
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _syncQueueDbHelperProvider =
    Provider<DatabaseHelper>((_) => DatabaseHelper());

final syncQueueLocalDataSourceProvider =
    Provider<SyncQueueLocalDataSource>((ref) {
  return SyncQueueLocalDataSourceImpl(
    ref.watch(_syncQueueDbHelperProvider),
  );
});
