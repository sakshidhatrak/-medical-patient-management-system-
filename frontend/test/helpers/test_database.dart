import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:medical_patient_management/core/database/database_helper.dart';

/// Initialise sqflite_common_ffi once per test process.
void initTestDatabase() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

var _dbCounter = 0;

/// Returns a [DatabaseHelper] backed by a fresh isolated SQLite database.
/// Uses a unique temp file per call so tests never share state.
Future<DatabaseHelper> buildTestDb() async {
  final dir = Directory.systemTemp;
  final path = p.join(dir.path, 'medimanage_test_${++_dbCounter}.db');

  // Remove any leftover file from a previous failed run.
  final file = File(path);
  if (file.existsSync()) file.deleteSync();

  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS patients (
            id TEXT PRIMARY KEY, first_name TEXT NOT NULL,
            last_name TEXT NOT NULL, date_of_birth TEXT NOT NULL,
            gender TEXT NOT NULL, phone TEXT NOT NULL,
            email TEXT, address TEXT, blood_type TEXT, allergies TEXT,
            created_at TEXT NOT NULL, updated_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_patients_name ON patients(last_name, first_name)',
        );
        await db.execute('''
          CREATE TABLE IF NOT EXISTS patient_details (
            patient_id TEXT PRIMARY KEY,
            visits_json TEXT NOT NULL DEFAULT '[]',
            vitals_json TEXT,
            emergency_contact_json TEXT,
            reports_json TEXT NOT NULL DEFAULT '[]',
            FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE
          )
        ''');
      },
    ),
  );

  return DatabaseHelper.forTest(db);
}
