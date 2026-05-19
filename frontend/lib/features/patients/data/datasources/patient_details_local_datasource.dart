import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../domain/entities/medical_report_entity.dart';
import '../../domain/entities/treatment_entity.dart';
import '../../domain/entities/vitals_entity.dart';

abstract interface class PatientDetailsLocalDataSource {
  Future<List<TreatmentEntity>> getVisits(String patientId);
  Future<void> saveVisit(TreatmentEntity visit);

  Future<VitalsEntity?> getVitals(String patientId);
  Future<void> saveVitals(VitalsEntity vitals);

  Future<EmergencyContactEntity?> getEmergencyContact(String patientId);
  Future<void> saveEmergencyContact(
      String patientId, EmergencyContactEntity contact);

  Future<List<MedicalReportEntity>> getReports(String patientId);
  Future<void> saveReports(
      String patientId, List<MedicalReportEntity> reports);
}

class PatientDetailsLocalDataSourceImpl
    implements PatientDetailsLocalDataSource {
  final DatabaseHelper _dbHelper;

  PatientDetailsLocalDataSourceImpl(this._dbHelper);

  static const _table = 'patient_details';

  // ── Row helpers ─────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _getRow(
      Database db, String patientId) async {
    final rows =
        await db.query(_table, where: 'patient_id = ?', whereArgs: [patientId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _ensureRow(Database db, String patientId) async {
    await db.insert(
      _table,
      {
        'patient_id': patientId,
        'visits_json': '[]',
        'reports_json': '[]',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // ── Visits ───────────────────────────────────────────────────────────────────

  @override
  Future<List<TreatmentEntity>> getVisits(String patientId) async {
    try {
      final db = await _dbHelper.database;
      final row = await _getRow(db, patientId);
      if (row == null) return [];
      final list =
          jsonDecode(row['visits_json'] as String) as List<dynamic>;
      return list
          .map((j) => _treatmentFromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const CacheException('Failed to read visits.', code: 'DB_READ');
    }
  }

  @override
  Future<void> saveVisit(TreatmentEntity visit) async {
    try {
      final db = await _dbHelper.database;
      await _ensureRow(db, visit.patientId);
      final row = await _getRow(db, visit.patientId);
      final visits =
          (jsonDecode(row!['visits_json'] as String) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      visits.add(_treatmentToJson(visit));
      await db.update(
        _table,
        {'visits_json': jsonEncode(visits)},
        where: 'patient_id = ?',
        whereArgs: [visit.patientId],
      );
    } catch (_) {
      throw const CacheException('Failed to save visit.', code: 'DB_WRITE');
    }
  }

  // ── Vitals ───────────────────────────────────────────────────────────────────

  @override
  Future<VitalsEntity?> getVitals(String patientId) async {
    try {
      final db = await _dbHelper.database;
      final row = await _getRow(db, patientId);
      if (row == null || row['vitals_json'] == null) return null;
      return _vitalsFromJson(
          jsonDecode(row['vitals_json'] as String) as Map<String, dynamic>);
    } catch (_) {
      throw const CacheException('Failed to read vitals.', code: 'DB_READ');
    }
  }

  @override
  Future<void> saveVitals(VitalsEntity vitals) async {
    try {
      final db = await _dbHelper.database;
      await _ensureRow(db, vitals.patientId);
      await db.update(
        _table,
        {'vitals_json': jsonEncode(_vitalsToJson(vitals))},
        where: 'patient_id = ?',
        whereArgs: [vitals.patientId],
      );
    } catch (_) {
      throw const CacheException('Failed to save vitals.', code: 'DB_WRITE');
    }
  }

  // ── Emergency contact ────────────────────────────────────────────────────────

  @override
  Future<EmergencyContactEntity?> getEmergencyContact(
      String patientId) async {
    try {
      final db = await _dbHelper.database;
      final row = await _getRow(db, patientId);
      if (row == null || row['emergency_contact_json'] == null) return null;
      return _emergencyFromJson(
          jsonDecode(row['emergency_contact_json'] as String)
              as Map<String, dynamic>);
    } catch (_) {
      throw const CacheException(
          'Failed to read emergency contact.', code: 'DB_READ');
    }
  }

  @override
  Future<void> saveEmergencyContact(
      String patientId, EmergencyContactEntity contact) async {
    try {
      final db = await _dbHelper.database;
      await _ensureRow(db, patientId);
      await db.update(
        _table,
        {
          'emergency_contact_json':
              jsonEncode(_emergencyToJson(contact))
        },
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );
    } catch (_) {
      throw const CacheException(
          'Failed to save emergency contact.', code: 'DB_WRITE');
    }
  }

  // ── Reports ──────────────────────────────────────────────────────────────────

  @override
  Future<List<MedicalReportEntity>> getReports(String patientId) async {
    try {
      final db = await _dbHelper.database;
      final row = await _getRow(db, patientId);
      if (row == null) return [];
      final list =
          jsonDecode(row['reports_json'] as String) as List<dynamic>;
      return list
          .map((j) => _reportFromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const CacheException('Failed to read reports.', code: 'DB_READ');
    }
  }

  @override
  Future<void> saveReports(
      String patientId, List<MedicalReportEntity> reports) async {
    try {
      final db = await _dbHelper.database;
      await _ensureRow(db, patientId);
      final row = await _getRow(db, patientId);
      final existing =
          (jsonDecode(row!['reports_json'] as String) as List<dynamic>)
              .cast<Map<String, dynamic>>();
      for (final r in reports) {
        existing.add(_reportToJson(r));
      }
      await db.update(
        _table,
        {'reports_json': jsonEncode(existing)},
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );
    } catch (_) {
      throw const CacheException('Failed to save reports.', code: 'DB_WRITE');
    }
  }

  // ── Serialization helpers ────────────────────────────────────────────────────

  Map<String, dynamic> _treatmentToJson(TreatmentEntity e) => {
        'patientId': e.patientId,
        'chiefComplaint': e.chiefComplaint,
        'diagnosis': e.diagnosis,
        'treatmentPlan': e.treatmentPlan,
        'medications': e.medications,
        'existingConditions': e.existingConditions,
        'doctorAssigned': e.doctorAssigned,
        'department': e.department,
        'visitType': e.visitType.name,
        'appointmentDateTime': e.appointmentDateTime?.toIso8601String(),
        'notes': e.notes,
        'weightKg': e.weightKg,
        'bloodPressure': e.bloodPressure,
        'temperature': e.temperature,
        'followUpInstructions': e.followUpInstructions,
      };

  TreatmentEntity _treatmentFromJson(Map<String, dynamic> j) => TreatmentEntity(
        patientId: j['patientId'] as String,
        chiefComplaint: j['chiefComplaint'] as String,
        diagnosis: j['diagnosis'] as String?,
        treatmentPlan: j['treatmentPlan'] as String?,
        medications:
            (j['medications'] as List<dynamic>?)?.cast<String>() ?? [],
        existingConditions:
            (j['existingConditions'] as List<dynamic>?)?.cast<String>() ?? [],
        doctorAssigned: j['doctorAssigned'] as String?,
        department: j['department'] as String?,
        visitType: VisitType.values.firstWhere(
          (v) => v.name == j['visitType'],
          orElse: () => VisitType.newVisit,
        ),
        appointmentDateTime: j['appointmentDateTime'] != null
            ? DateTime.parse(j['appointmentDateTime'] as String)
            : null,
        notes: j['notes'] as String?,
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        bloodPressure: j['bloodPressure'] as String?,
        temperature: (j['temperature'] as num?)?.toDouble(),
        followUpInstructions: j['followUpInstructions'] as String?,
      );

  Map<String, dynamic> _vitalsToJson(VitalsEntity e) => {
        'patientId': e.patientId,
        'heightCm': e.heightCm,
        'weightKg': e.weightKg,
        'bloodPressure': e.bloodPressure,
        'sugarLevel': e.sugarLevel,
        'pulseRate': e.pulseRate,
        'oxygenLevel': e.oxygenLevel,
        'temperature': e.temperature,
        'recordedAt': e.recordedAt.toIso8601String(),
      };

  VitalsEntity _vitalsFromJson(Map<String, dynamic> j) => VitalsEntity(
        patientId: j['patientId'] as String,
        heightCm: (j['heightCm'] as num?)?.toDouble(),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
        bloodPressure: j['bloodPressure'] as String?,
        sugarLevel: (j['sugarLevel'] as num?)?.toDouble(),
        pulseRate: j['pulseRate'] as int?,
        oxygenLevel: (j['oxygenLevel'] as num?)?.toDouble(),
        temperature: (j['temperature'] as num?)?.toDouble(),
        recordedAt: DateTime.parse(j['recordedAt'] as String),
      );

  Map<String, dynamic> _emergencyToJson(EmergencyContactEntity e) => {
        'name': e.name,
        'phone': e.phone,
        'relationship': e.relationship,
        'insuranceProvider': e.insuranceProvider,
        'insuranceNumber': e.insuranceNumber,
      };

  EmergencyContactEntity _emergencyFromJson(Map<String, dynamic> j) =>
      EmergencyContactEntity(
        name: j['name'] as String?,
        phone: j['phone'] as String?,
        relationship: j['relationship'] as String?,
        insuranceProvider: j['insuranceProvider'] as String?,
        insuranceNumber: j['insuranceNumber'] as String?,
      );

  Map<String, dynamic> _reportToJson(MedicalReportEntity e) => {
        'id': e.id,
        'patientId': e.patientId,
        'fileName': e.fileName,
        'extension': e.extension,
        'reportType': e.reportType.name,
        'fileSizeBytes': e.fileSizeBytes,
        'bytes': base64Encode(e.bytes),
        'uploadedAt': e.uploadedAt.toIso8601String(),
      };

  MedicalReportEntity _reportFromJson(Map<String, dynamic> j) =>
      MedicalReportEntity(
        id: j['id'] as String,
        patientId: j['patientId'] as String,
        fileName: j['fileName'] as String,
        extension: j['extension'] as String,
        reportType: ReportType.values.firstWhere(
          (r) => r.name == j['reportType'],
          orElse: () => ReportType.medicalReport,
        ),
        fileSizeBytes: j['fileSizeBytes'] as int,
        bytes: base64Decode(j['bytes'] as String),
        uploadedAt: DateTime.parse(j['uploadedAt'] as String),
      );
}
