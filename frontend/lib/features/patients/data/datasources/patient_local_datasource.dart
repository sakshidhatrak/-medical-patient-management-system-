import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/error/exceptions.dart';
import '../models/patient_model.dart';

abstract interface class PatientLocalDataSource {
  Future<List<PatientModel>> getPatients({
    required int limit,
    required int offset,
    String? search,
  });

  Future<PatientModel?> getPatientById(String id);

  Future<void> upsertPatient(PatientModel patient);

  Future<void> upsertPatients(List<PatientModel> patients);

  Future<void> deletePatient(String id);

  Future<List<PatientModel>> getPendingPatients();

  Future<void> markAsSynced(String patientId);
}

class PatientLocalDataSourceImpl implements PatientLocalDataSource {
  final DatabaseHelper _dbHelper;

  PatientLocalDataSourceImpl(this._dbHelper);

  static const String _table = 'patients';

  @override
  Future<List<PatientModel>> getPatients({
    required int limit,
    required int offset,
    String? search,
  }) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        _table,
        limit: limit,
        offset: offset,
        where: search != null
            ? 'first_name LIKE ? OR last_name LIKE ? OR phone LIKE ?'
            : null,
        whereArgs: search != null
            ? ['%$search%', '%$search%', '%$search%']
            : null,
        orderBy: 'last_name ASC, first_name ASC',
      );
      return rows.map(PatientModel.fromSqlite).toList();
    } catch (e) {
      throw CacheException('Failed to fetch patients from cache.', code: 'DB_READ');
    }
  }

  @override
  Future<PatientModel?> getPatientById(String id) async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(_table, where: 'id = ?', whereArgs: [id]);
      if (rows.isEmpty) return null;
      return PatientModel.fromSqlite(rows.first);
    } catch (e) {
      throw CacheException('Failed to fetch patient from cache.', code: 'DB_READ');
    }
  }

  @override
  Future<void> upsertPatient(PatientModel patient) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        _table,
        patient.toSqlite(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheException('Failed to save patient to cache.', code: 'DB_WRITE');
    }
  }

  @override
  Future<void> upsertPatients(List<PatientModel> patients) async {
    try {
      final db = await _dbHelper.database;
      final batch = db.batch();
      for (final p in patients) {
        batch.insert(
          _table,
          p.toSqlite(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      throw CacheException('Failed to save patients to cache.', code: 'DB_BATCH_WRITE');
    }
  }

  @override
  Future<void> deletePatient(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw CacheException('Failed to delete patient from cache.', code: 'DB_DELETE');
    }
  }

  @override
  Future<List<PatientModel>> getPendingPatients() async {
    try {
      final db = await _dbHelper.database;
      final rows = await db.query(
        _table,
        where: 'sync_status = ?',
        whereArgs: ['pending'],
      );
      return rows.map(PatientModel.fromSqlite).toList();
    } catch (e) {
      throw CacheException('Failed to fetch pending patients.', code: 'DB_READ');
    }
  }

  @override
  Future<void> markAsSynced(String patientId) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        _table,
        {'sync_status': 'synced'},
        where: 'id = ?',
        whereArgs: [patientId],
      );
    } catch (e) {
      throw CacheException('Failed to mark patient as synced.', code: 'DB_WRITE');
    }
  }
}

