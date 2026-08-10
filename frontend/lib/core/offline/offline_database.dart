import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Neurosurgery offline SQLite database.
/// Only opens on mobile (not on web).
class OfflineDatabase {
  static final OfflineDatabase _instance = OfflineDatabase._();
  // Cache the Future so concurrent callers all await the same open operation.
  // Without this, ??= is not atomic across awaits and _open() can be called
  // multiple times concurrently, which causes sqflite to deadlock on migration.
  Future<Database>? _dbFuture;

  OfflineDatabase._();
  factory OfflineDatabase() => _instance;

  Future<Database> get database {
    if (kIsWeb) {
      throw UnsupportedError('SQLite unavailable on web.');
    }
    // If a previous open attempt failed, reset so the next call retries.
    return _dbFuture ??= _openSafe();
  }

  Future<Database> _openSafe() async {
    try {
      return await _open();
    } catch (e) {
      _dbFuture = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'neuro_offline.db'),
      version: 5,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _repairOrphanedVisits,
    );
  }

  // Finds visits whose patient_id no longer exists in the patients table
  // (happens when the server assigned a numeric ID to a UUID patient) and
  // re-links them to the correct patient.
  //
  // Two-pass strategy:
  //   1. Fast path — look up patient_id_map for a known UUID→numeric mapping.
  //   2. Slow path — find nearest active patient by creation time using Dart
  //      DateTime parsing (timezone-aware; SQLite STRFTIME ignores tz offsets).
  //      Window: 24 hours (generous to cover multi-step wizard fill time).
  //
  // Called at DB open AND after _syncFromApi purges orphan patients (the visit
  // only becomes orphaned when the UUID patient is removed, not before).
  Future<void> _repairOrphanedVisits(Database db) async {
    final orphans = await db.rawQuery('''
      SELECT v.id, v.patient_id, v.created_at, v.data_json
      FROM visits v
      WHERE NOT EXISTS (
        SELECT 1 FROM patients p WHERE p.id = v.patient_id AND p.is_active = 1
      )
      AND v.is_active = 1
    ''');

    if (orphans.isEmpty) return;

    // Pre-fetch all active patients for Dart-side timestamp matching.
    final allPatients = await db.query(
      'patients',
      columns: ['id', 'created_at'],
      where: 'is_active = 1',
    );

    for (final row in orphans) {
      final visitId   = row['id'] as String;
      final oldPid    = row['patient_id'] as String?;
      final createdAt = row['created_at'] as String?;
      if (createdAt == null) continue;

      String? newPatientId;

      // Pass 1: patient_id_map lookup (available for patients synced in v41+)
      if (oldPid != null) {
        final mapped = await db.query(
          'patient_id_map',
          where: 'client_id = ?',
          whereArgs: [oldPid],
        );
        if (mapped.isNotEmpty) {
          newPatientId = mapped.first['server_id'] as String?;
        }
      }

      // Pass 2: nearest patient by creation time (handles timezone offsets)
      if (newPatientId == null) {
        DateTime? visitTime;
        try {
          visitTime = DateTime.parse(createdAt).toUtc();
        } catch (_) {
          continue;
        }

        String? bestId;
        int bestDiff = 86401; // 1 s beyond 24-h window

        for (final p in allPatients) {
          final pStr = p['created_at'] as String?;
          if (pStr == null) continue;
          try {
            final pTime = DateTime.parse(pStr).toUtc();
            final diff = (visitTime.millisecondsSinceEpoch -
                    pTime.millisecondsSinceEpoch)
                .abs() ~/
                1000;
            if (diff < bestDiff) {
              bestDiff = diff;
              bestId = p['id'] as String?;
            }
          } catch (_) {}
        }

        if (bestId == null) continue;
        newPatientId = bestId;

        // Cache this UUID→numeric mapping so remapFromIdMap works in future
        // sessions without needing another timestamp scan (covers patients
        // created before the patient_id_map table existed in v41).
        if (oldPid != null) {
          try {
            await db.insert(
              'patient_id_map',
              {'client_id': oldPid, 'server_id': newPatientId},
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          } catch (_) {}
        }
      }

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
          where: 'id = ?', whereArgs: [visitId]);
      debugPrint('[DB] Repaired orphaned visit $visitId → patient $newPatientId');

      // Reset queued sync attempts with the corrected patient ID.
      final queued = await db.query('sync_queue',
          where: 'entity_type = ? AND entity_id = ?',
          whereArgs: ['visits', visitId]);
      for (final q in queued) {
        try {
          final payload =
              jsonDecode(q['payload'] as String) as Map<String, dynamic>;
          payload['patientId'] = newPatientId;
          if (payload.containsKey('patient_id')) {
            payload['patient_id'] = newPatientId;
          }
          await db.update('sync_queue',
              {'payload': jsonEncode(payload), 'attempts': 0},
              where: 'id = ?', whereArgs: [q['id']]);
        } catch (_) {}
      }
    }
  }

  /// Public entry point so patient_provider can trigger repair AFTER purging
  /// orphaned patients (visits only become orphaned after the UUID patient is
  /// removed, which is after the initial onOpen repair runs).
  Future<void> repairOrphanedVisits() async {
    if (kIsWeb) return;
    final db = await database;
    await _repairOrphanedVisits(db);
  }

  Future<void> _onCreate(Database db, int _) async {
    final batch = db.batch();
    _createSchema(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      batch.execute('ALTER TABLE patients ADD COLUMN data_json TEXT');
      batch.execute('ALTER TABLE visits ADD COLUMN data_json TEXT');
      batch.execute('ALTER TABLE surgeries ADD COLUMN data_json TEXT');
      _createExaminationsTable(batch);
      _createPrescriptionsTable(batch);
      _createDrugsCacheTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 3) {
      final batch = db.batch();
      _createPhotosTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 5) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS patient_id_map (
            client_id TEXT PRIMARY KEY,
            server_id TEXT NOT NULL
          )
        ''');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // Add audit columns to all tables.
      // Wrapped in try-catch: earlier app versions may have already created
      // these tables with the v4 schema (because helper methods were updated
      // before the version bump), so "duplicate column" errors are safe to ignore.
      final stmts = [
        'ALTER TABLE patients ADD COLUMN created_by TEXT',
        'ALTER TABLE patients ADD COLUMN updated_by TEXT',
        'ALTER TABLE visits ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE visits ADD COLUMN created_by TEXT',
        'ALTER TABLE visits ADD COLUMN updated_by TEXT',
        'ALTER TABLE surgeries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE surgeries ADD COLUMN created_by TEXT',
        'ALTER TABLE surgeries ADD COLUMN updated_by TEXT',
        "ALTER TABLE photos ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'",
        'ALTER TABLE photos ADD COLUMN updated_at TEXT',
        'ALTER TABLE photos ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE photos ADD COLUMN created_by TEXT',
        'ALTER TABLE photos ADD COLUMN updated_by TEXT',
        'ALTER TABLE examinations ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE examinations ADD COLUMN created_at TEXT',
        'ALTER TABLE examinations ADD COLUMN created_by TEXT',
        'ALTER TABLE examinations ADD COLUMN updated_by TEXT',
        'ALTER TABLE prescriptions ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE prescriptions ADD COLUMN created_at TEXT',
        'ALTER TABLE prescriptions ADD COLUMN created_by TEXT',
        'ALTER TABLE prescriptions ADD COLUMN updated_by TEXT',
      ];
      for (final sql in stmts) {
        try {
          await db.execute(sql);
        } catch (_) {
          // Ignore — column likely already exists from a prior schema version.
        }
      }
    }
  }

  void _createSchema(Batch batch) {
    // ── Patients cache ───────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id           TEXT PRIMARY KEY,
        prn          TEXT NOT NULL,
        first_name   TEXT NOT NULL,
        last_name    TEXT NOT NULL DEFAULT '',
        age          INTEGER,
        date_of_birth TEXT,
        sex          TEXT,
        phone        TEXT,
        address      TEXT,
        notes        TEXT,
        data_json    TEXT,
        sync_status  TEXT NOT NULL DEFAULT 'synced',
        is_active    INTEGER NOT NULL DEFAULT 1,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        created_by   TEXT,
        updated_by   TEXT
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_patients_prn ON patients(prn)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_patients_name ON patients(first_name,last_name)');

    // ── Visits cache ────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS visits (
        id                  TEXT PRIMARY KEY,
        patient_id          TEXT NOT NULL,
        visit_date          TEXT NOT NULL,
        visit_type          TEXT NOT NULL DEFAULT 'opd',
        complaints          TEXT,
        examination         TEXT,
        clinical_impression TEXT,
        plan                TEXT,
        notes               TEXT,
        status              TEXT NOT NULL DEFAULT 'draft',
        data_json           TEXT,
        sync_status         TEXT NOT NULL DEFAULT 'pending',
        is_active           INTEGER NOT NULL DEFAULT 1,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        created_by          TEXT,
        updated_by          TEXT
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_visits_patient ON visits(patient_id)');

    // ── Surgeries cache ─────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS surgeries (
        id                  TEXT PRIMARY KEY,
        patient_id          TEXT NOT NULL,
        surgery_date        TEXT NOT NULL,
        your_role           TEXT,
        pre_op_diagnosis    TEXT,
        procedure           TEXT,
        primary_surgeon     TEXT,
        assistant_surgeons  TEXT,
        anesthesia_type     TEXT,
        anesthesiologist    TEXT,
        implants            TEXT,
        intraop_findings    TEXT,
        ot_notes            TEXT,
        complications       TEXT,
        post_op_plan        TEXT,
        status              TEXT NOT NULL DEFAULT 'draft',
        data_json           TEXT,
        sync_status         TEXT NOT NULL DEFAULT 'pending',
        is_active           INTEGER NOT NULL DEFAULT 1,
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL,
        created_by          TEXT,
        updated_by          TEXT
      )
    ''');

    // ── Photos cache ─────────────────────────────────────────────
    _createPhotosTable(batch);

    // ── Examinations cache ──────────────────────────────────────
    _createExaminationsTable(batch);

    // ── Prescriptions cache ─────────────────────────────────────
    _createPrescriptionsTable(batch);

    // ── Drugs master cache ──────────────────────────────────────
    _createDrugsCacheTable(batch);

    // ── Patient ID map (client UUID → server numeric ID) ────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS patient_id_map (
        client_id TEXT PRIMARY KEY,
        server_id TEXT NOT NULL
      )
    ''');

    // ── Sync queue ──────────────────────────────────────────────
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id           TEXT PRIMARY KEY,
        entity_type  TEXT NOT NULL,
        entity_id    TEXT NOT NULL,
        operation    TEXT NOT NULL,
        payload      TEXT NOT NULL,
        queued_at    TEXT NOT NULL,
        attempts     INTEGER NOT NULL DEFAULT 0,
        last_error   TEXT
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_sync_entity ON sync_queue(entity_type,entity_id)');
  }

  void _createPhotosTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS photos (
        id           TEXT PRIMARY KEY,
        patient_id   TEXT NOT NULL,
        visit_id     TEXT,
        surgery_id   TEXT,
        storage_path TEXT NOT NULL,
        url          TEXT,
        category     TEXT NOT NULL,
        caption      TEXT,
        local_path   TEXT,
        file_size    INTEGER,
        mime_type    TEXT,
        is_uploaded  INTEGER NOT NULL DEFAULT 0,
        sync_status  TEXT NOT NULL DEFAULT 'synced',
        is_active    INTEGER NOT NULL DEFAULT 1,
        created_at   TEXT NOT NULL,
        updated_at   TEXT,
        created_by   TEXT,
        updated_by   TEXT
      )
    ''');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_photos_patient ON photos(patient_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_photos_visit ON photos(visit_id)');
    batch.execute(
        'CREATE INDEX IF NOT EXISTS idx_off_photos_uploaded ON photos(is_uploaded)');
  }

  void _createExaminationsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS examinations (
        visit_id    TEXT PRIMARY KEY,
        patient_id  TEXT NOT NULL,
        data_json   TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT,
        updated_at  TEXT NOT NULL,
        created_by  TEXT,
        updated_by  TEXT
      )
    ''');
  }

  void _createPrescriptionsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS prescriptions (
        visit_id    TEXT PRIMARY KEY,
        patient_id  TEXT NOT NULL,
        data_json   TEXT NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'synced',
        is_active   INTEGER NOT NULL DEFAULT 1,
        created_at  TEXT,
        updated_at  TEXT NOT NULL,
        created_by  TEXT,
        updated_by  TEXT
      )
    ''');
  }

  void _createDrugsCacheTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS drugs_cache (
        id        TEXT PRIMARY KEY,
        data_json TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = await _dbFuture;
    await db?.close();
    _dbFuture = null;
  }
}
