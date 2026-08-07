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
      state = models.map((m) => m.toEntity()).toList();
    } catch (_) {}
  }

  void refresh() => Future.microtask(() => _syncFromApi(arg));

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
    // Reject blank visits — all meaningful fields are empty.
    final hasData = [complaints, examination, clinicalImpression, plan, notes]
        .any((f) => f != null && f.trim().isNotEmpty);
    if (!hasData) return null;

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
    // Always cache locally first (works on both web and mobile)
    await _local.upsert(model.toFullJson());

    if (_online) {
      try {
        final saved = isNew
            ? await _ds.createVisit(model)
            : await _ds.updateVisit(model);
        // Remove the temp client-UUID entry; server assigned a different (Long) ID.
        if (isNew && saved.id != model.id) {
          await _local.purge(model.id);
        }
        await _local.upsert(saved.toFullJson());
        final entity = saved.toEntity();
        if (isNew) {
          state = [entity, ...state];
        } else {
          state = state.map((v) => v.id == entity.id ? entity : v).toList();
        }
        return entity;
      } catch (e) {
        debugPrint('[VisitProvider] API error (will sync later): $e');
        // Fall through to offline path — visit is already cached locally.
      }
    }

    // Offline or API-unreachable: enqueue for sync when connection restores
    await _queue.enqueue(
      entityType: 'visits',
      entityId: model.id,
      operation: isNew ? 'insert' : 'update',
      payload: {...model.toFullJson(), 'patientId': model.patientId},
    );
    await _local.markPending(model.id);
    final pendingEntity = model.toEntity().copyWith(syncStatus: 'pending');
    if (isNew) {
      state = [pendingEntity, ...state];
    } else {
      state = state.map((v) => v.id == model.id ? pendingEntity : v).toList();
    }
    return pendingEntity;
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
    await _local.upsert(model.toFullJson());

    if (ref.read(isOnlineProvider)) {
      try {
        final saved = await _ds.updateVisit(model);
        await _local.upsert(saved.toFullJson());
        state = saved.toEntity();
        return true;
      } catch (e) {
        debugPrint('[VisitEditProvider] API error: $e');
        return false;
      }
    }

    await ref.read(offlineQueueProvider).enqueue(
      entityType: 'visits',
      entityId: model.id,
      operation: 'update',
      payload: {...model.toFullJson(), 'patientId': model.patientId},
    );
    return true;
  }
}

final visitEditProvider =
    NotifierProviderFamily<VisitEditNotifier, VisitEntity?, String>(
        VisitEditNotifier.new);
