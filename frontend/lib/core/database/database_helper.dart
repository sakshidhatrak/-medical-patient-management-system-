import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';

// sqflite v2 compiles on web (it ships web stubs) but throws at runtime if
// you try to open a database. Guard every entry point with kIsWeb so we
// never reach the runtime call on web builds.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  Database? _db;

  DatabaseHelper._();

  /// Production singleton — always returns the same instance.
  factory DatabaseHelper() => _instance;

  /// Test-only constructor — injects a pre-opened [Database] directly,
  /// bypassing the singleton and the file-based initialisation.
  @visibleForTesting
  DatabaseHelper.forTest(Database db) : _db = db;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite is not available on Flutter Web. '
        'Use the in-memory mock datasources instead.',
      );
    }
    return _db ??= await _init();
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConfig.dbName);
    return openDatabase(
      path,
      version: AppConfig.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createUsersTable(batch);
    _createPatientsTable(batch);
    _createAppointmentsTable(batch);
    _createMedicalRecordsTable(batch);
    _createPatientDetailsTable(batch);
    _createSyncQueueTable(batch);
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final batch = db.batch();
      _createPatientDetailsTable(batch);
      await batch.commit(noResult: true);
    }
    if (oldVersion < 3) {
      final batch = db.batch();
      batch.execute(
        "ALTER TABLE patients ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'pending'",
      );
      _createSyncQueueTable(batch);
      await batch.commit(noResult: true);
    }
  }

  void _createUsersTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id          TEXT PRIMARY KEY,
        email       TEXT NOT NULL UNIQUE,
        first_name  TEXT NOT NULL,
        last_name   TEXT NOT NULL,
        role        TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
      )
    ''');
  }

  void _createPatientsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id            TEXT PRIMARY KEY,
        first_name    TEXT NOT NULL,
        last_name     TEXT NOT NULL,
        date_of_birth TEXT NOT NULL,
        gender        TEXT NOT NULL,
        phone         TEXT NOT NULL,
        email         TEXT,
        address       TEXT,
        blood_type    TEXT,
        allergies     TEXT,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        sync_status   TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(last_name, first_name)',
    );
  }

  void _createAppointmentsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id           TEXT PRIMARY KEY,
        patient_id   TEXT NOT NULL,
        doctor_id    TEXT NOT NULL,
        scheduled_at TEXT NOT NULL,
        status       TEXT NOT NULL DEFAULT "scheduled",
        notes        TEXT,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_appts_patient ON appointments(patient_id)',
    );
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_appts_date ON appointments(scheduled_at)',
    );
  }

  void _createMedicalRecordsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS medical_records (
        id           TEXT PRIMARY KEY,
        patient_id   TEXT NOT NULL,
        doctor_id    TEXT NOT NULL,
        diagnosis    TEXT NOT NULL,
        treatment    TEXT,
        prescription TEXT,
        notes        TEXT,
        visit_date   TEXT NOT NULL,
        created_at   TEXT NOT NULL,
        updated_at   TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_records_patient ON medical_records(patient_id)',
    );
  }

  void _createSyncQueueTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id          TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL DEFAULT 'patient',
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        queued_at   TEXT NOT NULL,
        attempts    INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  void _createPatientDetailsTable(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS patient_details (
        patient_id              TEXT PRIMARY KEY,
        visits_json             TEXT NOT NULL DEFAULT '[]',
        vitals_json             TEXT,
        emergency_contact_json  TEXT,
        reports_json            TEXT NOT NULL DEFAULT '[]',
        FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async => _db?.close();
}
