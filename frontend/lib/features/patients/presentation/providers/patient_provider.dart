import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/offline/offline_database.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/datasources/patient_supabase_datasource.dart';
import '../../data/models/patient_model.dart';
import '../../domain/entities/patient_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';

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

  // IDs of patients whose _syncPatientToApi() call is currently in-flight.
  // Used to avoid purging genuinely-pending patients during _syncFromApi().
  final _inflightIds = <String>{};

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
          final syncStatus = r['sync_status'] as String? ?? 'synced';
          final jsonStr = r['data_json'] as String?;
          if (jsonStr != null) {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            decoded['syncStatus'] = syncStatus;
            return PatientModel.fromJson(decoded).toEntity();
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
            'syncStatus': syncStatus,
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
      // On refresh, preserve locally-pending patients not yet in the API response.
      final List<PatientEntity> merged;
      if (refresh) {
        final apiIds = entities.map((e) => e.id).toSet();
        final pendingLocal = state.patients
            .where((p) => !apiIds.contains(p.id) && p.syncStatus == 'pending')
            .toList();

        if (pendingLocal.isNotEmpty) {
          // Determine which pending patients are genuinely waiting vs orphaned.
          // Orphans: not in the sync queue AND no in-flight _syncPatientToApi().
          // Example: v30 created patient P1 locally but the server assigned a
          // different UUID — P1 sits in SQLite as 'pending' forever.
          final queuedIds = (await _queue.pending())
              .where((item) => item.entityType == 'patients')
              .map((item) => item.entityId)
              .toSet();
          final keepPending = <PatientEntity>[];
          for (final p in pendingLocal) {
            if (queuedIds.contains(p.id) || _inflightIds.contains(p.id)) {
              keepPending.add(p); // Genuinely pending — keep
            } else {
              // Orphan: the backend already has this patient under a different
              // (numeric) ID. This happens when the user logs out before
              // _syncPatientToApi() completes. Match by PRN to find the
              // server entity, then remap all local visits/surgeries/photos
              // before purging so they remain visible after login.
              final matches = entities.where((e) => e.prn == p.prn);
              if (matches.isNotEmpty) {
                final serverId = matches.first.id;
                await ref.read(patientIdMapProvider).insert(p.id, serverId);
                await ref.read(localVisitCacheProvider).remapPatientId(p.id, serverId);
                await ref.read(localSurgeryCacheProvider).remapPatientId(p.id, serverId);
                await ref.read(localPhotoStoreProvider).remapPatientId(p.id, serverId);
                await ref.read(offlineQueueProvider).remapPatientIdInQueue(p.id, serverId);
                unawaited(ref.read(syncEngineProvider).syncAll());
              }
              await _local.purge(p.id); // Orphan — remove from SQLite
            }
          }
          // Repair visits that became orphaned because their UUID patient was
          // just purged above. The onOpen repair ran before this purge, so it
          // needs a second pass now that the UUID patients are gone.
          await ref.read(offlineDatabaseProvider).repairOrphanedVisits();
          merged = [...entities, ...keepPending];
        } else {
          merged = [...entities];
        }
      } else {
        merged = [...state.patients, ...entities];
      }
      state = state.copyWith(
        patients: merged,
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

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, page: 1);
    await _syncFromApi(refresh: true);
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
    String? notes,
  }) async {
    try {
      final now = DateTime.now();
      final model = PatientModel(
        id: const Uuid().v4(),
        prn: generatePrn(firstName),
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
        notes: notes,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );

      // 1. Save locally immediately — always instant, works offline.
      await _local.upsert(model.toFullJson());
      await _local.markPending(model.id);

      // 2. Return local entity right away so UI never blocks on network.
      final entity = model.toEntity().copyWith(syncStatus: 'pending');
      state = state.copyWith(patients: [entity, ...state.patients]);

      // 3. Sync to backend in background — fire-and-forget.
      if (_online) {
        _inflightIds.add(model.id);
        unawaited(_syncPatientToApi(model, isNew: true)
            .whenComplete(() => _inflightIds.remove(model.id)));
      } else {
        await _queue.enqueue(
          entityType: 'patients',
          entityId: model.id,
          operation: 'insert',
          payload: model.toFullJson(),
        );
        await _local.markPending(model.id);
      }

      return entity;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> _syncPatientToApi(PatientModel model,
      {required bool isNew}) async {
    try {
      final saved = isNew
          ? await _ds.createPatient(model)
          : await _ds.updatePatient(model);
      if (isNew && saved.id != model.id) {
        // Record mapping BEFORE purging — resolves UUID → numeric ID for any
        // in-flight or pending photo uploads from the same session.
        await ref.read(patientIdMapProvider).insert(model.id, saved.id);
        await _local.purge(model.id);
        // Remap all local records that still reference the old client UUID.
        await ref.read(localVisitCacheProvider).remapPatientId(model.id, saved.id);
        await ref.read(localSurgeryCacheProvider).remapPatientId(model.id, saved.id);
        await ref.read(localPhotoStoreProvider).remapPatientId(model.id, saved.id);
        await ref.read(offlineQueueProvider).remapPatientIdInQueue(model.id, saved.id);
        // Flush queued visits/surgeries that were saved with the old UUID
        // patient ID — they now have the correct numeric ID in their payload.
        unawaited(ref.read(syncEngineProvider).syncAll());
        // Upload any photos that were saved locally while patient sync was
        // pending (race condition: photo step reached before Render responded).
        // Use saved.id (numeric) — photos were remapped to new patient_id above.
        unawaited(ref.read(photoProvider(saved.id).notifier).syncPending());
      }
      await _local.upsert(saved.toFullJson());
      final entity = saved.toEntity();
      state = state.copyWith(
        patients: isNew
            ? [entity, ...state.patients.where((p) => p.id != model.id && p.id != entity.id)]
            : state.patients.map((p) => p.id == entity.id ? entity : p).toList(),
      );
    } catch (e) {
      // Queue for later retry
      await _queue.enqueue(
        entityType: 'patients',
        entityId: model.id,
        operation: isNew ? 'insert' : 'update',
        payload: model.toFullJson(),
      );
      await _local.markPending(model.id);
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

      // Sync to backend in background — fire-and-forget.
      if (_online) {
        unawaited(_syncPatientToApi(model, isNew: false));
      } else {
        await _queue.enqueue(
          entityType: 'patients',
          entityId: model.id,
          operation: 'update',
          payload: model.toFullJson(),
        );
      }
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
  // 1. Return local cache immediately — never block on the network.
  final row = await ref.read(localPatientCacheProvider).getById(id);
  if (row != null) {
    final jsonStr = row['data_json'] as String?;
    if (jsonStr != null) {
      // Refresh from API in the background so next load has fresh data.
      if (ref.read(isOnlineProvider)) {
        ref
            .read(patientDataSourceProvider)
            .getPatientById(id)
            .then((model) =>
                ref.read(localPatientCacheProvider).upsert(model.toFullJson()))
            .ignore();
      }
      return PatientModel.fromJson(
              jsonDecode(jsonStr) as Map<String, dynamic>)
          .toEntity();
    }
  }
  // 2. No local data yet (first ever load) — must wait for API.
  if (ref.read(isOnlineProvider)) {
    try {
      final model =
          await ref.read(patientDataSourceProvider).getPatientById(id);
      await ref.read(localPatientCacheProvider).upsert(model.toFullJson());
      return model.toEntity();
    } catch (_) {}
  }
  return null;
});
