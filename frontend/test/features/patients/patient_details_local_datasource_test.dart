import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/features/patients/data/datasources/patient_details_local_datasource.dart';
import 'package:medical_patient_management/features/patients/data/datasources/patient_local_datasource.dart';
import 'package:medical_patient_management/features/patients/data/models/patient_model.dart';
import 'package:medical_patient_management/features/patients/domain/entities/emergency_contact_entity.dart';
import 'package:medical_patient_management/features/patients/domain/entities/medical_report_entity.dart';
import 'package:medical_patient_management/features/patients/domain/entities/treatment_entity.dart';
import 'package:medical_patient_management/features/patients/domain/entities/vitals_entity.dart';

import '../../helpers/test_database.dart';

const _pid = 'test-patient-1';
const _now = '2024-01-15T08:00:00.000Z';

void main() {
  late PatientDetailsLocalDataSourceImpl ds;

  setUpAll(initTestDatabase);

  setUp(() async {
    final db = await buildTestDb();
    // Seed a patient row so FK constraints are satisfied.
    final patientDs = PatientLocalDataSourceImpl(db);
    await patientDs.upsertPatient(PatientModel(
      id: _pid,
      firstName: 'Test',
      lastName: 'Patient',
      dateOfBirth: '1990-01-01',
      gender: 'male',
      phone: '+1 555-0000',
      createdAt: _now,
      updatedAt: _now,
    ));
    ds = PatientDetailsLocalDataSourceImpl(db);
  });

  // ── Visits ─────────────────────────────────────────────────────────────────

  group('Visits', () {
    test('returns empty list when no visits saved', () async {
      final visits = await ds.getVisits(_pid);
      expect(visits, isEmpty);
    });

    test('saves and retrieves a visit', () async {
      final visit = TreatmentEntity(
        patientId: _pid,
        chiefComplaint: 'Headache',
        diagnosis: 'Migraine',
        treatmentPlan: 'Rest and fluids',
        medications: ['Ibuprofen'],
        visitType: VisitType.newVisit,
        appointmentDateTime: DateTime(2024, 1, 15, 10, 0),
        notes: 'Mild case',
      );

      await ds.saveVisit(visit);
      final visits = await ds.getVisits(_pid);

      expect(visits.length, 1);
      expect(visits.first.chiefComplaint, 'Headache');
      expect(visits.first.diagnosis, 'Migraine');
      expect(visits.first.medications, ['Ibuprofen']);
      expect(visits.first.visitType, VisitType.newVisit);
    });

    test('appends multiple visits for same patient', () async {
      await ds.saveVisit(TreatmentEntity(
        patientId: _pid,
        chiefComplaint: 'Visit 1',
        visitType: VisitType.newVisit,
      ));
      await ds.saveVisit(TreatmentEntity(
        patientId: _pid,
        chiefComplaint: 'Visit 2',
        visitType: VisitType.followUp,
      ));

      final visits = await ds.getVisits(_pid);
      expect(visits.length, 2);
      expect(visits[0].chiefComplaint, 'Visit 1');
      expect(visits[1].chiefComplaint, 'Visit 2');
    });

    test('persists all visit fields correctly', () async {
      final dt = DateTime(2024, 6, 15, 9, 30);
      await ds.saveVisit(TreatmentEntity(
        patientId: _pid,
        chiefComplaint: 'Chest pain',
        diagnosis: 'Angina',
        treatmentPlan: 'Medication',
        medications: ['Aspirin', 'Nitroglycerine'],
        existingConditions: ['Hypertension'],
        doctorAssigned: 'Dr. Smith',
        department: 'Cardiology',
        visitType: VisitType.emergency,
        appointmentDateTime: dt,
        notes: 'Urgent',
        weightKg: 72.5,
        bloodPressure: '140/90',
        temperature: 37.2,
        followUpInstructions: 'Return in 1 week',
      ));

      final visits = await ds.getVisits(_pid);
      final v = visits.first;

      expect(v.medications, ['Aspirin', 'Nitroglycerine']);
      expect(v.existingConditions, ['Hypertension']);
      expect(v.visitType, VisitType.emergency);
      expect(v.appointmentDateTime, dt);
      expect(v.weightKg, 72.5);
      expect(v.bloodPressure, '140/90');
      expect(v.temperature, 37.2);
      expect(v.followUpInstructions, 'Return in 1 week');
    });
  });

  // ── Vitals ─────────────────────────────────────────────────────────────────

  group('Vitals', () {
    test('returns null when no vitals saved', () async {
      final vitals = await ds.getVitals(_pid);
      expect(vitals, isNull);
    });

    test('saves and retrieves vitals', () async {
      final vitals = VitalsEntity(
        patientId: _pid,
        heightCm: 175.0,
        weightKg: 70.0,
        bloodPressure: '120/80',
        sugarLevel: 95.0,
        pulseRate: 72,
        oxygenLevel: 98.5,
        temperature: 36.6,
        recordedAt: DateTime(2024, 1, 15),
      );

      await ds.saveVitals(vitals);
      final result = await ds.getVitals(_pid);

      expect(result, isNotNull);
      expect(result!.heightCm, 175.0);
      expect(result.weightKg, 70.0);
      expect(result.bloodPressure, '120/80');
      expect(result.pulseRate, 72);
      expect(result.oxygenLevel, 98.5);
    });

    test('overrides existing vitals on re-save', () async {
      await ds.saveVitals(VitalsEntity(
        patientId: _pid,
        weightKg: 65.0,
        recordedAt: DateTime(2024, 1, 1),
      ));
      await ds.saveVitals(VitalsEntity(
        patientId: _pid,
        weightKg: 68.0,
        recordedAt: DateTime(2024, 6, 1),
      ));

      final result = await ds.getVitals(_pid);
      expect(result!.weightKg, 68.0);
    });

    test('calculates BMI correctly when height and weight present', () async {
      await ds.saveVitals(VitalsEntity(
        patientId: _pid,
        heightCm: 170.0,
        weightKg: 70.0,
        recordedAt: DateTime(2024, 1, 15),
      ));

      final result = await ds.getVitals(_pid);
      expect(result!.bmi, closeTo(24.2, 0.1));
    });
  });

  // ── Emergency Contact ──────────────────────────────────────────────────────

  group('Emergency Contact', () {
    test('returns null when no contact saved', () async {
      final contact = await ds.getEmergencyContact(_pid);
      expect(contact, isNull);
    });

    test('saves and retrieves emergency contact', () async {
      const contact = EmergencyContactEntity(
        name: 'Jane Doe',
        phone: '+1 555-9999',
        relationship: 'Spouse',
        insuranceProvider: 'BlueCross',
        insuranceNumber: 'BC-123456',
      );

      await ds.saveEmergencyContact(_pid, contact);
      final result = await ds.getEmergencyContact(_pid);

      expect(result, isNotNull);
      expect(result!.name, 'Jane Doe');
      expect(result.phone, '+1 555-9999');
      expect(result.relationship, 'Spouse');
      expect(result.insuranceProvider, 'BlueCross');
      expect(result.insuranceNumber, 'BC-123456');
    });

    test('updates existing emergency contact', () async {
      await ds.saveEmergencyContact(
        _pid,
        const EmergencyContactEntity(name: 'Old Name', phone: '+1 000-0000'),
      );
      await ds.saveEmergencyContact(
        _pid,
        const EmergencyContactEntity(name: 'New Name', phone: '+1 111-1111'),
      );

      final result = await ds.getEmergencyContact(_pid);
      expect(result!.name, 'New Name');
    });
  });

  // ── Medical Reports ────────────────────────────────────────────────────────

  group('Medical Reports', () {
    test('returns empty list when no reports saved', () async {
      final reports = await ds.getReports(_pid);
      expect(reports, isEmpty);
    });

    test('saves and retrieves a report with file bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final report = MedicalReportEntity(
        id: 'report-1',
        patientId: _pid,
        fileName: 'blood_test.pdf',
        extension: 'pdf',
        reportType: ReportType.labReport,
        fileSizeBytes: bytes.length,
        bytes: bytes,
        uploadedAt: DateTime(2024, 1, 15),
      );

      await ds.saveReports(_pid, [report]);
      final results = await ds.getReports(_pid);

      expect(results.length, 1);
      expect(results.first.fileName, 'blood_test.pdf');
      expect(results.first.reportType, ReportType.labReport);
      expect(results.first.bytes, bytes);
    });

    test('appends multiple report batches', () async {
      final bytes = Uint8List.fromList([0]);
      final report1 = MedicalReportEntity(
        id: 'r-1',
        patientId: _pid,
        fileName: 'report1.pdf',
        extension: 'pdf',
        reportType: ReportType.medicalReport,
        fileSizeBytes: 1,
        bytes: bytes,
        uploadedAt: DateTime(2024, 1, 10),
      );
      final report2 = MedicalReportEntity(
        id: 'r-2',
        patientId: _pid,
        fileName: 'xray.png',
        extension: 'png',
        reportType: ReportType.scan,
        fileSizeBytes: 1,
        bytes: bytes,
        uploadedAt: DateTime(2024, 2, 1),
      );

      await ds.saveReports(_pid, [report1]);
      await ds.saveReports(_pid, [report2]);

      final results = await ds.getReports(_pid);
      expect(results.length, 2);
      expect(results.map((r) => r.id), containsAll(['r-1', 'r-2']));
    });
  });
}
