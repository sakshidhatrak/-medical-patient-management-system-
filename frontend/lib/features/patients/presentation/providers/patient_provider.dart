import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/datasources/patient_supabase_datasource.dart';
import '../../data/models/patient_model.dart';
import '../../domain/entities/patient_entity.dart';

// ── Infrastructure ────────────────────────────────────────────────

final patientDataSourceProvider = Provider<PatientSupabaseDataSource>((ref) =>
    PatientApiDataSourceImpl(ref.watch(apiClientProvider)));

// ── State ─────────────────────────────────────────────────────────

class PatientsState {
  final List<PatientEntity> patients;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? search;
  final String? error;

  const PatientsState({
    this.patients = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 1,
    this.search,
    this.error,
  });

  PatientsState copyWith({
    List<PatientEntity>? patients,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? search,
    String? error,
    bool clearError = false,
  }) =>
      PatientsState(
        patients: patients ?? this.patients,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        page: page ?? this.page,
        search: search ?? this.search,
        error: clearError ? null : error ?? this.error,
      );
}

// ── Notifier ──────────────────────────────────────────────────────

class PatientsNotifier extends Notifier<PatientsState> {
  static const _pageSize = 20;

  PatientSupabaseDataSource get _ds => ref.read(patientDataSourceProvider);
  LocalPatientCache get _local => ref.read(localPatientCacheProvider);
  OfflineQueue get _queue => ref.read(offlineQueueProvider);
  bool get _online => ref.read(isOnlineProvider);

  @override
  PatientsState build() {
    Future.microtask(_init);
    return const PatientsState(isLoading: true);
  }

  Future<void> _init() async {
    // 1. Show cached data immediately (works on web via localStorage).
    await _loadLocal();
    // 2. Refresh from API in background.
    await _syncFromApi(refresh: true);
  }

  Future<void> _loadLocal() async {
    try {
      final rows = await _local.getAll(search: state.search);
      if (rows.isNotEmpty) {
        final entities = rows.map((r) {
          final jsonStr = r['data_json'] as String?;
          if (jsonStr != null) {
            return PatientModel.fromJson(
                    jsonDecode(jsonStr) as Map<String, dynamic>)
                .toEntity();
          }
          // Legacy rows without data_json — reconstruct from columns.
          return PatientModel.fromJson({
            'id': r['id'],
            'prn': r['prn'],
            'firstName': r['first_name'],
            'lastName': r['last_name'],
            'age': r['age'],
            'dateOfBirth': r['date_of_birth'],
            'sex': r['sex'],
            'phone': r['phone'],
            'address': r['address'],
            'notes': r['notes'],
            'isActive': (r['is_active'] as int? ?? 1) == 1,
            'createdAt': r['created_at'],
            'updatedAt': r['updated_at'],
          }).toEntity();
        }).toList();
        state = state.copyWith(
            patients: entities, isLoading: false, clearError: true);
      }
    } catch (_) {}
  }

  Future<void> _syncFromApi({bool refresh = false}) async {
    if (!_online) {
      state = state.copyWith(isLoading: false);
      return;
    }
    try {
      final page = refresh ? 1 : state.page;
      final models = await _ds
          .getPatients(page: page, pageSize: _pageSize, search: state.search)
          .timeout(const Duration(seconds: 15));
      // Cache every fetched patient locally.
      for (final m in models) {
        await _local.upsert(m.toFullJson());
      }
      final entities = models.map((m) => m.toEntity()).toList();
      state = state.copyWith(
        patients:
            refresh ? entities : [...state.patients, ...entities],
        isLoading: false,
        hasMore: models.length == _pageSize,
        page: page + 1,
        clearError: true,
      );
    } on TimeoutException {
      state = state.copyWith(isLoading: false,
          error: 'Connection timed out. Showing cached data.');
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void refresh() {
    state = state.copyWith(isLoading: true, page: 1);
    Future.microtask(() => _syncFromApi(refresh: true));
  }

  void loadMore() {
    if (!state.isLoading && state.hasMore) _syncFromApi();
  }

  void search(String query) {
    state = state.copyWith(
        search: query.isEmpty ? null : query, page: 1, isLoading: true);
    Future.microtask(() async {
      await _loadLocal();
      await _syncFromApi(refresh: true);
    });
  }

  Future<PatientEntity?> createPatient({
    required String firstName,
    String lastName = '',
    int? age,
    DateTime? dob,
    String? sex,
    String? phone,
    String? address,
    String? altPhone,
    String? email,
    String? idProofType,
    String? idProofNumber,
    String? weight,
    String? bloodPressure,
    String? temperature,
    String? allergies,
    String? medicalHistory,
    String? previousHistory,
    String? chiefComplaint,
    String? examGeneral,
    String? examNeurological,
    String? clinicalDiagnosis,
    String? imaging,
    String? otherInvestigations,
    String? impression,
    String? plan,
    String? treatment,
    String? treatmentNotes,
    String? advice,
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final model = PatientModel(
        id: const Uuid().v4(),
        prn: generatePrn(),
        firstName: firstName,
        lastName: lastName,
        age: age,
        dateOfBirth: dob?.toIso8601String().split('T').first,
        sex: sex,
        phone: phone,
        address: address,
        altPhone: altPhone,
        email: email,
        idProofType: idProofType,
        idProofNumber: idProofNumber,
        weight: weight,
        bloodPressure: bloodPressure,
        temperature: temperature,
        allergies: allergies,
        medicalHistory: medicalHistory,
        previousHistory: previousHistory,
        chiefComplaint: chiefComplaint,
        examGeneral: examGeneral,
        examNeurological: examNeurological,
        clinicalDiagnosis: clinicalDiagnosis,
        imaging: imaging,
        otherInvestigations: otherInvestigations,
        impression: impression,
        plan: plan,
        treatment: treatment,
        treatmentNotes: treatmentNotes,
        advice: advice,
        notes: notes,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );

      // Save locally first so UI is always fast (web: localStorage, mobile: SQLite).
      await _local.upsert(model.toFullJson());

      if (_online) {
        final saved = await _ds.createPatient(model);
        await _local.upsert(saved.toFullJson());
        final entity = saved.toEntity();
        state = state.copyWith(patients: [entity, ...state.patients]);
        return entity;
      }

      // Offline: enqueue for sync when connection restores
      await _queue.enqueue(
        entityType: 'patients',
        entityId: model.id,
        operation: 'insert',
        payload: model.toFullJson(),
      );
      final entity = model.toEntity();
      state = state.copyWith(patients: [entity, ...state.patients]);
      return entity;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<PatientEntity?> updatePatient(PatientEntity patient) async {
    try {
      final model = PatientModel.fromEntity(patient);

      // Optimistic local update.
      await _local.upsert(model.toFullJson());
      state = state.copyWith(
        patients: state.patients
            .map((p) => p.id == patient.id ? patient : p)
            .toList(),
      );

      if (_online) {
        try {
          final saved = await _ds.updatePatient(model);
          await _local.upsert(saved.toFullJson());
          final entity = saved.toEntity();
          state = state.copyWith(
            patients: state.patients
                .map((p) => p.id == entity.id ? entity : p)
                .toList(),
          );
          return entity;
        } catch (_) {}
      }

      // Offline: queue update.
      await _queue.enqueue(
        entityType: 'patients',
        entityId: model.id,
        operation: 'update',
        payload: model.toFullJson(),
      );
      return patient;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<List<PatientEntity>> searchDuplicates(
      String name, String? phone) async {
    try {
      final models = await _ds.searchDuplicates(name, phone);
      return models.map((m) => m.toEntity()).toList();
    } catch (_) {
      return [];
    }
  }
}

final patientsProvider =
    NotifierProvider<PatientsNotifier, PatientsState>(PatientsNotifier.new);

final patientByIdProvider =
    FutureProvider.family<PatientEntity?, String>((ref, id) async {
  // Try API first if online.
  if (ref.read(isOnlineProvider)) {
    try {
      final ds = ref.read(patientDataSourceProvider);
      final model = await ds.getPatientById(id);
      // Update local cache.
      ref.read(localPatientCacheProvider).upsert(model.toFullJson());
      return model.toEntity();
    } catch (_) {}
  }
  // Fall back to local cache (works on web via localStorage).
  final row = await ref.read(localPatientCacheProvider).getById(id);
  if (row != null) {
    final jsonStr = row['data_json'] as String?;
    if (jsonStr != null) {
      return PatientModel.fromJson(
              jsonDecode(jsonStr) as Map<String, dynamic>)
          .toEntity();
    }
  }
  return null;
});
