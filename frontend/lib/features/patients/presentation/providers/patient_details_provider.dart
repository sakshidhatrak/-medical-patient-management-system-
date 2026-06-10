import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../data/datasources/patient_details_local_datasource.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../domain/entities/medical_report_entity.dart';
import '../../domain/entities/treatment_entity.dart';
import '../../domain/entities/vitals_entity.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final _detailsDbProvider =
    Provider<DatabaseHelper>((_) => DatabaseHelper());

final patientDetailsLocalDataSourceProvider =
    Provider<PatientDetailsLocalDataSource>((ref) {
  return PatientDetailsLocalDataSourceImpl(ref.watch(_detailsDbProvider));
});

// ── Patient details state ────────────────────────────────────────────────────

class PatientDetails {
  final List<TreatmentEntity> visits;
  final VitalsEntity? vitals;
  final EmergencyContactEntity? emergencyContact;
  final List<MedicalReportEntity> reports;

  const PatientDetails({
    this.visits = const [],
    this.vitals,
    this.emergencyContact,
    this.reports = const [],
  });

  TreatmentEntity? get treatment =>
      visits.isEmpty ? null : visits.last;

  PatientDetails copyWith({
    List<TreatmentEntity>? visits,
    VitalsEntity? vitals,
    EmergencyContactEntity? emergencyContact,
    List<MedicalReportEntity>? reports,
  }) =>
      PatientDetails(
        visits: visits ?? this.visits,
        vitals: vitals ?? this.vitals,
        emergencyContact: emergencyContact ?? this.emergencyContact,
        reports: reports ?? this.reports,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class PatientDetailsNotifier extends Notifier<Map<String, PatientDetails>> {
  @override
  Map<String, PatientDetails> build() => {};

  PatientDetailsLocalDataSource get _local =>
      ref.read(patientDetailsLocalDataSourceProvider);

  PatientDetails _getOrCreate(String patientId) =>
      state[patientId] ?? const PatientDetails();

  /// Load all details for a patient from SQLite (mobile only).
  Future<void> loadDetailsForPatient(String patientId) async {
    if (kIsWeb) return;
    try {
      final visits = await _local.getVisits(patientId);
      final vitals = await _local.getVitals(patientId);
      final emergency = await _local.getEmergencyContact(patientId);
      final reports = await _local.getReports(patientId);
      state = {
        ...state,
        patientId: PatientDetails(
          visits: visits,
          vitals: vitals,
          emergencyContact: emergency,
          reports: reports,
        ),
      };
    } catch (_) {
      // Non-fatal — UI shows empty state if load fails
    }
  }

  void saveTreatment(TreatmentEntity treatment) {
    if (!kIsWeb) _local.saveVisit(treatment).ignore();
    final existing = _getOrCreate(treatment.patientId);
    state = {
      ...state,
      treatment.patientId:
          existing.copyWith(visits: [...existing.visits, treatment]),
    };
  }

  void addVisit(TreatmentEntity visit) => saveTreatment(visit);

  void saveVitals(VitalsEntity vitals) {
    if (!kIsWeb) _local.saveVitals(vitals).ignore();
    final updated = _getOrCreate(vitals.patientId).copyWith(vitals: vitals);
    state = {...state, vitals.patientId: updated};
  }

  void saveEmergencyContact(
      String patientId, EmergencyContactEntity contact) {
    if (!kIsWeb) _local.saveEmergencyContact(patientId, contact).ignore();
    final updated =
        _getOrCreate(patientId).copyWith(emergencyContact: contact);
    state = {...state, patientId: updated};
  }

  void saveReports(String patientId, List<MedicalReportEntity> reports) {
    if (!kIsWeb) _local.saveReports(patientId, reports).ignore();
    final existing = _getOrCreate(patientId);
    final updated =
        existing.copyWith(reports: [...existing.reports, ...reports]);
    state = {...state, patientId: updated};
  }

  PatientDetails? getDetails(String patientId) => state[patientId];
}

final patientDetailsProvider =
    NotifierProvider<PatientDetailsNotifier, Map<String, PatientDetails>>(
  PatientDetailsNotifier.new,
);

final patientDetailDataProvider =
    Provider.family<PatientDetails?, String>((ref, patientId) {
  return ref.watch(patientDetailsProvider)[patientId];
});
