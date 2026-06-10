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
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int _) async {
    final batch = db.batch();

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
        sync_status  TEXT NOT NULL DEFAULT 'synced',
        is_active    INTEGER NOT NULL DEFAULT 1,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL
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
        sync_status         TEXT NOT NULL DEFAULT 'pending',
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL
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
        sync_status         TEXT NOT NULL DEFAULT 'pending',
        created_at          TEXT NOT NULL,
        updated_at          TEXT NOT NULL
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

    await batch.commit(noResult: true);
  }

  Future<void> close() async => _db?.close();
}
