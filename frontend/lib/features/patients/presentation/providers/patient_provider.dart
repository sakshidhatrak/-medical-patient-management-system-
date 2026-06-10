import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../data/datasources/patient_supabase_datasource.dart';
import '../../data/models/patient_model.dart';
import '../../domain/entities/patient_entity.dart';

// ── Infrastructure ────────────────────────────────────────────────

final _supabaseProvider = Provider((_) => sb.Supabase.instance.client);

final patientDataSourceProvider = Provider<PatientSupabaseDataSource>((ref) =>
    PatientSupabaseDataSourceImpl(ref.watch(_supabaseProvider)));

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

  PatientSupabaseDataSource get _ds =>
      ref.read(patientDataSourceProvider);

  @override
  PatientsState build() {
    Future.microtask(_load);
    return const PatientsState(isLoading: true);
  }

  Future<void> _load({bool refresh = false, int attempt = 0}) async {
    if (refresh) state = state.copyWith(isLoading: true, page: 1);
    try {
      final page = refresh ? 1 : state.page;
      final models = await _ds
          .getPatients(
            page: page,
            pageSize: _pageSize,
            search: state.search,
          )
          .timeout(const Duration(seconds: 10));
      final entities = models.map((m) => m.toEntity()).toList();
      state = state.copyWith(
        patients: refresh ? entities : [...state.patients, ...entities],
        isLoading: false,
        hasMore: models.length == _pageSize,
        page: page + 1,
        clearError: true,
      );
    } on TimeoutException {
      // Retry once — handles Supabase session init race on first load
      if (attempt < 1) {
        await Future.delayed(const Duration(seconds: 2));
        return _load(refresh: refresh, attempt: attempt + 1);
      }
      state = state.copyWith(
          isLoading: false,
          error: 'Connection timed out. Check your network and tap retry.');
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void refresh() => _load(refresh: true);

  void loadMore() {
    if (!state.isLoading && state.hasMore) _load();
  }

  void search(String query) {
    state = state.copyWith(search: query.isEmpty ? null : query);
    _load(refresh: true);
  }

  Future<PatientEntity?> createPatient({
    required String firstName,
    String lastName = '',
    int? age,
    DateTime? dob,
    String? sex,
    String? phone,
    String? address,
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
        notes: notes,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );
      final saved = await _ds.createPatient(model);
      final entity = saved.toEntity();
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
      final saved = await _ds.updatePatient(model);
      final entity = saved.toEntity();
      state = state.copyWith(
        patients: state.patients
            .map((p) => p.id == entity.id ? entity : p)
            .toList(),
      );
      return entity;
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
  final ds = ref.read(patientDataSourceProvider);
  try {
    return (await ds.getPatientById(id)).toEntity();
  } catch (_) {
    return null;
  }
});
