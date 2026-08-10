import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/datasources/visit_supabase_datasource.dart';
import '../../data/models/visit_model.dart';
import '../../domain/entities/visit_entity.dart';

final visitDataSourceProvider = Provider<VisitSupabaseDataSource>((ref) =>
    VisitApiDataSourceImpl(ref.watch(apiClientProvider)));

// ── Per-patient visits ────────────────────────────────────────────

class VisitsNotifier extends FamilyNotifier<List<VisitEntity>, String> {
  VisitSupabaseDataSource get _ds => ref.read(visitDataSourceProvider);
  LocalVisitCache get _local => ref.read(localVisitCacheProvider);
  OfflineQueue get _queue => ref.read(offlineQueueProvider);
  bool get _online => ref.read(isOnlineProvider);

  @override
  List<VisitEntity> build(String arg) {
    Future.microtask(() => _init(arg));
    return [];
  }

  Future<void> _init(String patientId) async {
    await _loadLocal(patientId);
    await _syncFromApi(patientId);
  }

  Future<void> _loadLocal(String patientId) async {
    try {
      final rows = await _local.getForPatient(patientId);
      if (rows.isNotEmpty) {
        state = rows.map((r) {
          final syncStatus = r['sync_status'] as String? ?? 'synced';
          final js = r['data_json'] as String?;
          if (js != null) {
            final decoded = jsonDecode(js) as Map<String, dynamic>;
            decoded['syncStatus'] = syncStatus;
            return VisitModel.fromJson(decoded).toEntity();
          }
          return VisitModel.fromJson({
            'id': r['id'],
            'patientId': r['patient_id'],
            'visitDate': r['visit_date'],
            'visitType': r['visit_type'],
            'complaints': r['complaints'],
            'examination': r['examination'],
            'clinicalImpression': r['clinical_impression'],
            'plan': r['plan'],
            'notes': r['notes'],
            'status': r['status'],
            'isActive': (r['is_active'] as int? ?? 1) == 1,
            'createdAt': r['created_at'],
            'updatedAt': r['updated_at'],
            'syncStatus': syncStatus,
          }).toEntity();
        }).toList();
      }
    } catch (_) {}
  }

  Future<void> _syncFromApi(String patientId) async {
    if (!_online) return;
    try {
      final models = await _ds.getVisitsForPatient(patientId);
      for (final m in models) {
        await _local.upsert(m.toFullJson());
      }
      // Preserve locally-saved pending visits not yet returned by the API
      // (e.g. saved while Render was cold-starting, still in the sync queue).
      final apiIds = models.map((m) => m.id).toSet();
      final pendingLocal = state
          .where((v) => !apiIds.contains(v.id) && v.syncStatus == 'pending')
          .toList();
      state = [...models.map((m) => m.toEntity()), ...pendingLocal];
    } catch (_) {}
  }

  Future<void> refresh() => _syncFromApi(arg);

  Future<VisitEntity?> createVisit({
    required String patientId,
    VisitType type = VisitType.opd,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final model = VisitModel(
        id: const Uuid().v4(),
        patientId: patientId,
        visitDate: now.toIso8601String(),
        visitType: type.value,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );
      return _saveVisit(model, isNew: true);
    } catch (_) {
      return null;
    }
  }

  Future<VisitEntity?> createFullVisit({
    required String patientId,
    VisitType type = VisitType.opd,
    DateTime? visitDate,
    String? complaints,
    String? examination,
    String? clinicalImpression,
    String? plan,
    String? notes,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final model = VisitModel(
        id: const Uuid().v4(),
        patientId: patientId,
        visitDate: (visitDate?.toUtc() ?? now).toIso8601String(),
        visitType: type.value,
        complaints: complaints,
        examination: examination,
        clinicalImpression: clinicalImpression,
        plan: plan,
        notes: notes,
        status: 'completed',
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );
      return _saveVisit(model, isNew: true);
    } catch (_) {
      return null;
    }
  }

  Future<VisitEntity?> saveVisit(VisitEntity visit) async {
    final model = VisitModel.fromEntity(visit);
    return _saveVisit(model, isNew: false);
  }

  Future<VisitEntity?> _saveVisit(VisitModel model,
      {required bool isNew}) async {
    // 1. Save to SQLite immediately — always instant, works offline.
    await _local.upsert(model.toFullJson());
    // Mark pending so on app-restart _loadLocal sees it as pending and
    // _syncFromApi preserves it until the API confirms.
    await _local.markPending(model.id);

    // 2. Return the local entity right away so the UI never blocks on network.
    final pendingEntity = model.toEntity().copyWith(syncStatus: 'pending');
    if (isNew) {
      state = [pendingEntity, ...state];
    } else {
      state = state.map((v) => v.id == model.id ? pendingEntity : v).toList();
    }

    // 3. Sync to backend in background — fire-and-forget.
    if (_online) {
      unawaited(_syncToApi(model, isNew: isNew));
    } else {
      await _queue.enqueue(
        entityType: 'visits',
        entityId: model.id,
        operation: isNew ? 'insert' : 'update',
        payload: {...model.toFullJson(), 'patientId': model.patientId},
      );
      await _local.markPending(model.id);
    }

    return pendingEntity;
  }

  Future<void> _syncToApi(VisitModel model, {required bool isNew}) async {
    // Re-read the cached row to pick up any patient_id remapping that may have
    // happened after the parent patient was assigned a new server-side numeric ID.
    VisitModel syncModel = model;
    try {
      final row = await _local.getById(model.id);
      if (row != null) {
        final storedPid = row['patient_id'] as String?;
        if (storedPid != null && storedPid != model.patientId) {
          final js = row['data_json'] as String?;
          if (js != null) {
            syncModel = VisitModel.fromJson(
                jsonDecode(js) as Map<String, dynamic>);
          }
        }
      }
    } catch (_) {}

    try {
      final saved = isNew
          ? await _ds.createVisit(syncModel)
          : await _ds.updateVisit(syncModel);
      if (isNew && saved.id != model.id) {
        // Remap prescriptions, examinations, and photos to the server-assigned
        // numeric ID BEFORE purging the UUID visit so nothing is orphaned.
        await _local.remapVisitId(model.id, saved.id);
        await _local.purge(model.id);
      }
      await _local.upsert(saved.toFullJson());
      final entity = saved.toEntity();
      if (isNew) {
        // Remove both the pending client-UUID entry AND any existing server-UUID
        // entry that may have been added concurrently by _syncFromApi().
        state = [entity, ...state.where((v) => v.id != model.id && v.id != entity.id).toList()];
      } else {
        state = state.map((v) => v.id == entity.id ? entity : v).toList();
      }
    } catch (e) {
      debugPrint('[VisitProvider] Background sync failed, queuing: $e');
      // Re-read patient_id from SQLite a final time in case the remap arrived
      // after we began but before the network call was made.
      String queuePatientId = syncModel.patientId;
      try {
        final row = await _local.getById(model.id);
        if (row != null) {
          queuePatientId =
              (row['patient_id'] as String?) ?? syncModel.patientId;
        }
      } catch (_) {}
      await _queue.enqueue(
        entityType: 'visits',
        entityId: model.id,
        operation: isNew ? 'insert' : 'update',
        payload: {...syncModel.toFullJson(), 'patientId': queuePatientId},
      );
      await _local.markPending(model.id);
    }
  }

  Future<void> deleteVisit(String id) async {
    if (_online) {
      try {
        await _ds.deleteVisit('$arg/$id');
      } catch (_) {}
    } else {
      await _queue.enqueue(
        entityType: 'visits',
        entityId: id,
        operation: 'delete',
        payload: {'patientId': arg},
      );
    }
    await _local.delete(id);
    state = state.where((v) => v.id != id).toList();
  }
}

final visitsProvider =
    NotifierProviderFamily<VisitsNotifier, List<VisitEntity>, String>(
        VisitsNotifier.new);

// ── Single visit editing ──────────────────────────────────────────
// arg format: "patientId/visitId"

class VisitEditNotifier extends FamilyNotifier<VisitEntity?, String> {
  VisitSupabaseDataSource get _ds => ref.read(visitDataSourceProvider);
  LocalVisitCache get _local => ref.read(localVisitCacheProvider);
  OfflineQueue get _queue => ref.read(offlineQueueProvider);
  bool get _online => ref.read(isOnlineProvider);

  @override
  VisitEntity? build(String arg) {
    Future.microtask(() => _load(arg));
    return null;
  }

  Future<void> _load(String arg) async {
    final parts = arg.split('/');
    final visitId = parts.length > 1 ? parts[1] : parts[0];

    // Show cached data immediately
    final row = await _local.getById(visitId);
    if (row != null) {
      final js = row['data_json'] as String?;
      if (js != null) {
        state = VisitModel.fromJson(
                jsonDecode(js) as Map<String, dynamic>)
            .toEntity();
      }
    }

    // Refresh from API if online
    if (_online) {
      try {
        final model = await _ds.getVisitById(arg);
        await _local.upsert(model.toFullJson());
        state = model.toEntity();
      } catch (_) {}
    }
  }

  void update(VisitEntity updated) => state = updated;

  Future<bool> save() async {
    if (state == null) return false;
    final model = VisitModel.fromEntity(state!);
    // Save locally first — always instant, never blocks UI.
    await _local.upsert(model.toFullJson());
    if (_online) {
      unawaited(_syncEditToApi(model));
    } else {
      await _queue.enqueue(
        entityType: 'visits',
        entityId: model.id,
        operation: 'update',
        payload: {...model.toFullJson(), 'patientId': model.patientId},
      );
    }
    return true;
  }

  Future<void> _syncEditToApi(VisitModel model) async {
    try {
      final saved = await _ds.updateVisit(model);
      await _local.upsert(saved.toFullJson());
      state = saved.toEntity();
    } catch (e) {
      debugPrint('[VisitEditProvider] Background sync failed: $e');
      await _queue.enqueue(
        entityType: 'visits',
        entityId: model.id,
        operation: 'update',
        payload: {...model.toFullJson(), 'patientId': model.patientId},
      );
    }
  }
}

final visitEditProvider =
    NotifierProviderFamily<VisitEditNotifier, VisitEntity?, String>(
        VisitEditNotifier.new);
