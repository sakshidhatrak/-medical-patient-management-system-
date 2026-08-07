import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Neurosurgery offline SQLite database.
/// Only opens on mobile (not on web).
class OfflineDatabase {
  static final OfflineDatabase _instance = OfflineDatabase._();
  Database? _db;

  OfflineDatabase._();
  factory OfflineDatabase() => _instance;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite unavailable on web.');
    }
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'neuro_offline.db'),
      version: 4,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
    if (oldVersion < 4) {
      // Add audit columns to all tables
      final stmts = [
        'ALTER TABLE patients ADD COLUMN created_by TEXT',
        'ALTER TABLE patients ADD COLUMN updated_by TEXT',
        'ALTER TABLE visits ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE visits ADD COLUMN created_by TEXT',
        'ALTER TABLE visits ADD COLUMN updated_by TEXT',
        'ALTER TABLE surgeries ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
        'ALTER TABLE surgeries ADD COLUMN created_by TEXT',
        'ALTER TABLE surgeries ADD COLUMN updated_by TEXT',
        'ALTER TABLE photos ADD COLUMN sync_status TEXT NOT NULL DEFAULT \'synced\'',
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
        await db.execute(sql);
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

  Future<void> close() async => _db?.close();
}
