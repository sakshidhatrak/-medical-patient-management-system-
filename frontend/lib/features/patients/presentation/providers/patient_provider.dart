import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/sync_service.dart';
import '../../../patients/data/datasources/patient_local_datasource.dart';
import '../../../patients/data/datasources/sync_queue_datasource.dart';
import '../../../patients/data/models/patient_model.dart';
import '../../domain/entities/patient_entity.dart';

// ── Infrastructure providers ─────────────────────────────────────────────────

final _databaseHelperProvider =
    Provider<DatabaseHelper>((_) => DatabaseHelper());

final patientLocalDataSourceProvider =
    Provider<PatientLocalDataSource>((ref) {
  return PatientLocalDataSourceImpl(ref.watch(_databaseHelperProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class PatientsState {
  final List<PatientEntity> patients;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? searchQuery;
  final Failure? failure;
  final Set<String> pendingSyncIds;

  const PatientsState({
    this.patients = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.currentPage = 1,
    this.searchQuery,
    this.failure,
    this.pendingSyncIds = const {},
  });

  PatientsState copyWith({
    List<PatientEntity>? patients,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? searchQuery,
    Failure? failure,
    bool clearFailure = false,
    Set<String>? pendingSyncIds,
  }) =>
      PatientsState(
        patients: patients ?? this.patients,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
        searchQuery: searchQuery ?? this.searchQuery,
        failure: clearFailure ? null : failure ?? this.failure,
        pendingSyncIds: pendingSyncIds ?? this.pendingSyncIds,
      );
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class PatientsNotifier extends Notifier<PatientsState> {
  PatientLocalDataSource get _local =>
      ref.read(patientLocalDataSourceProvider);

  SyncQueueLocalDataSource get _syncQueue =>
      ref.read(syncQueueLocalDataSourceProvider);

  @override
  PatientsState build() {
    // Auto-sync when connectivity is restored.
    ref.listen(isOnlineProvider, (prev, isOnline) {
      if (isOnline == true && prev == false) {
        _syncAndReload();
      }
    });
    _init();
    return const PatientsState(isLoading: true);
  }

  Future<void> _init() async {
    await _seedIfEmpty();
    await _loadFromDb();
  }

  Future<void> _seedIfEmpty() async {
    try {
      final existing = await _local.getPatients(limit: 1, offset: 0);
      if (existing.isEmpty) {
        final seeds = _kSeedPatients.map(PatientModel.fromEntity).toList();
        await _local.upsertPatients(seeds);
      }
    } catch (_) {
      // Non-fatal — app still works with empty list
    }
  }

  Future<void> _loadFromDb({String? search}) async {
    try {
      final models =
          await _local.getPatients(limit: 500, offset: 0, search: search);
      final pending = await _local.getPendingPatients();
      final pendingIds = pending.map((m) => m.id).toSet();
      state = state.copyWith(
        patients: models.map((m) => m.toEntity()).toList(),
        isLoading: false,
        clearFailure: true,
        pendingSyncIds: pendingIds,
      );
    } on CacheException catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: CacheFailure(e.message, code: e.code),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        failure: CacheFailure('Failed to load patients: $e'),
      );
    }
  }

  void loadPatients({bool refresh = false}) {
    if (refresh) state = state.copyWith(isLoading: true);
    _loadFromDb(search: state.searchQuery);
  }

  void loadMore() {}

  void search(String query) {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearFailure: true,
    );
    _loadFromDb(search: query.isEmpty ? null : query);
  }

  Future<bool> createPatient(PatientEntity patient) async {
    try {
      final model = PatientModel.fromEntity(patient);
      await _local.upsertPatient(model);
      await _syncQueue.enqueue(
        entityType: 'patient',
        entityId: patient.id,
        operation: 'create',
        payload: model.toJson(),
      );
      final newPending = {...state.pendingSyncIds, patient.id};
      state = state.copyWith(
        patients: [patient, ...state.patients],
        pendingSyncIds: newPending,
        clearFailure: true,
      );
      return true;
    } on CacheException {
      return false;
    }
  }

  Future<bool> updatePatient(PatientEntity patient) async {
    try {
      final model = PatientModel.fromEntity(patient);
      await _local.upsertPatient(model);
      await _syncQueue.enqueue(
        entityType: 'patient',
        entityId: patient.id,
        operation: 'update',
        payload: model.toJson(),
      );
      final newPending = {...state.pendingSyncIds, patient.id};
      state = state.copyWith(
        patients: state.patients
            .map((p) => p.id == patient.id ? patient : p)
            .toList(),
        pendingSyncIds: newPending,
        clearFailure: true,
      );
      return true;
    } on CacheException {
      return false;
    }
  }

  void deletePatient(String id) {
    _local.deletePatient(id).ignore();
    _syncQueue
        .enqueue(
          entityType: 'patient',
          entityId: id,
          operation: 'delete',
          payload: {'id': id},
        )
        .ignore();
    final newPending = {...state.pendingSyncIds}..remove(id);
    state = state.copyWith(
      patients: state.patients.where((p) => p.id != id).toList(),
      pendingSyncIds: newPending,
      clearFailure: true,
    );
  }

  /// Manually triggered sync (e.g. from the app bar sync button).
  Future<void> syncNow() async {
    await _syncAndReload();
  }

  Future<void> _syncAndReload() async {
    await ref
        .read(syncServiceProvider)
        .syncAll(ref.read(patientLocalDataSourceProvider));
    await _loadFromDb(search: state.searchQuery);
  }
}

final patientsProvider =
    NotifierProvider<PatientsNotifier, PatientsState>(PatientsNotifier.new);

// ── Detail provider ──────────────────────────────────────────────────────────

final patientDetailProvider =
    FutureProvider.family<PatientEntity, String>((ref, id) async {
  if (id == 'new') throw const NotFoundFailure('Use the create screen.');

  // First check already-loaded list (fast path, kept in sync by notifier).
  final loaded =
      ref.watch(patientsProvider).patients.where((p) => p.id == id).firstOrNull;
  if (loaded != null) return loaded;

  // Fallback: hit SQLite directly (e.g., during initial load).
  final local = ref.read(patientLocalDataSourceProvider);
  final model = await local.getPatientById(id);
  if (model == null) {
    throw const NotFoundFailure('Patient not found.', code: 'NOT_FOUND');
  }
  return model.toEntity();
});

// ── Seed data ─────────────────────────────────────────────────────────────────

final _t = DateTime(2024, 1, 15);

final _kSeedPatients = <PatientEntity>[
  PatientEntity(
    id: 'p-001',
    firstName: 'Sarah',
    lastName: 'Johnson',
    dateOfBirth: DateTime(1985, 3, 14),
    gender: Gender.female,
    phone: '+1 555-0101',
    email: 'sarah.johnson@email.com',
    address: '123 Oak Street, Boston, MA 02101',
    bloodType: 'A+',
    allergies: const ['Penicillin', 'Latex'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-002',
    firstName: 'Michael',
    lastName: 'Chen',
    dateOfBirth: DateTime(1972, 7, 22),
    gender: Gender.male,
    phone: '+1 555-0102',
    email: 'mchen@email.com',
    address: '456 Elm Ave, Chicago, IL 60601',
    bloodType: 'B+',
    allergies: const ['Sulfa drugs'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-003',
    firstName: 'Emily',
    lastName: 'Rodriguez',
    dateOfBirth: DateTime(1990, 11, 5),
    gender: Gender.female,
    phone: '+1 555-0103',
    email: 'emily.r@email.com',
    address: '789 Pine Rd, Miami, FL 33101',
    bloodType: 'O+',
    allergies: const [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-004',
    firstName: 'James',
    lastName: 'Williams',
    dateOfBirth: DateTime(1955, 1, 30),
    gender: Gender.male,
    phone: '+1 555-0104',
    email: 'jwilliams@email.com',
    address: '321 Maple Dr, Seattle, WA 98101',
    bloodType: 'AB-',
    allergies: const ['Aspirin', 'Ibuprofen'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-005',
    firstName: 'Aisha',
    lastName: 'Patel',
    dateOfBirth: DateTime(1998, 6, 18),
    gender: Gender.female,
    phone: '+1 555-0105',
    email: 'aisha.patel@email.com',
    address: '654 Cedar Ln, Austin, TX 78701',
    bloodType: 'A-',
    allergies: const ['Peanuts'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-006',
    firstName: 'Robert',
    lastName: 'Thompson',
    dateOfBirth: DateTime(1962, 9, 9),
    gender: Gender.male,
    phone: '+1 555-0106',
    email: 'rthompson@email.com',
    address: '987 Birch Blvd, Denver, CO 80201',
    bloodType: 'O-',
    allergies: const ['Codeine'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-007',
    firstName: 'Mei',
    lastName: 'Liu',
    dateOfBirth: DateTime(2001, 2, 14),
    gender: Gender.female,
    phone: '+1 555-0107',
    email: 'mei.liu@email.com',
    address: '159 Walnut St, San Francisco, CA 94101',
    bloodType: 'B-',
    allergies: const [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-008',
    firstName: 'Carlos',
    lastName: 'Martinez',
    dateOfBirth: DateTime(1978, 12, 3),
    gender: Gender.male,
    phone: '+1 555-0108',
    email: 'cmartinez@email.com',
    address: '753 Spruce Way, Phoenix, AZ 85001',
    bloodType: 'AB+',
    allergies: const ['Morphine', 'Latex'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-009',
    firstName: 'Grace',
    lastName: "O'Brien",
    dateOfBirth: DateTime(1945, 8, 27),
    gender: Gender.female,
    phone: '+1 555-0109',
    email: 'gobrien@email.com',
    address: '246 Ash Court, Portland, OR 97201',
    bloodType: 'A+',
    allergies: const ['Penicillin'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-010',
    firstName: 'David',
    lastName: 'Kim',
    dateOfBirth: DateTime(1988, 4, 19),
    gender: Gender.male,
    phone: '+1 555-0110',
    email: 'dkim@email.com',
    address: '864 Poplar Ave, Nashville, TN 37201',
    bloodType: 'O+',
    allergies: const [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-011',
    firstName: 'Fatima',
    lastName: 'Hassan',
    dateOfBirth: DateTime(1993, 10, 31),
    gender: Gender.female,
    phone: '+1 555-0111',
    email: 'fhassan@email.com',
    address: '531 Willow Pl, Minneapolis, MN 55401',
    bloodType: 'B+',
    allergies: const ['Shellfish'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-012',
    firstName: 'Thomas',
    lastName: 'Anderson',
    dateOfBirth: DateTime(1968, 5, 7),
    gender: Gender.male,
    phone: '+1 555-0112',
    email: 'tanderson@email.com',
    address: '975 Magnolia St, Atlanta, GA 30301',
    bloodType: 'A+',
    allergies: const ['Aspirin'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-013',
    firstName: 'Priya',
    lastName: 'Sharma',
    dateOfBirth: DateTime(2003, 7, 4),
    gender: Gender.female,
    phone: '+1 555-0113',
    email: 'psharma@email.com',
    address: '302 Lotus Ave, Houston, TX 77001',
    bloodType: 'O+',
    allergies: const [],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-014',
    firstName: 'Noah',
    lastName: 'Walker',
    dateOfBirth: DateTime(1995, 9, 22),
    gender: Gender.male,
    phone: '+1 555-0114',
    email: 'nwalker@email.com',
    address: '88 Riverside Dr, New York, NY 10001',
    bloodType: 'A+',
    allergies: const ['Sulfa drugs'],
    createdAt: _t,
    updatedAt: _t,
  ),
  PatientEntity(
    id: 'p-015',
    firstName: 'Elena',
    lastName: 'Petrov',
    dateOfBirth: DateTime(1960, 12, 1),
    gender: Gender.female,
    phone: '+1 555-0115',
    email: 'epetrov@email.com',
    address: '44 Birchwood Ct, Detroit, MI 48201',
    bloodType: 'AB+',
    allergies: const ['Latex', 'Penicillin'],
    createdAt: _t,
    updatedAt: _t,
  ),
];
