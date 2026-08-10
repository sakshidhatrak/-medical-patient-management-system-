import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../data/datasources/surgery_supabase_datasource.dart';
import '../../data/models/surgery_model.dart';
import '../../domain/entities/surgery_entity.dart';

final surgeryDataSourceProvider = Provider<SurgerySupabaseDataSource>((ref) =>
    SurgeryApiDataSourceImpl(ref.watch(apiClientProvider)));

class SurgeriesNotifier extends FamilyNotifier<List<SurgeryEntity>, String> {
  SurgerySupabaseDataSource get _ds => ref.read(surgeryDataSourceProvider);
  LocalSurgeryCache get _local => ref.read(localSurgeryCacheProvider);
  OfflineQueue get _queue => ref.read(offlineQueueProvider);
  bool get _online => ref.read(isOnlineProvider);

  @override
  List<SurgeryEntity> build(String arg) {
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
            return SurgeryModel.fromJson(decoded).toEntity();
          }
          return SurgeryModel.fromJson({
            'id': r['id'],
            'patientId': r['patient_id'],
            'surgeryDate': r['surgery_date'],
            'yourRole': r['your_role'],
            'preOpDiagnosis': r['pre_op_diagnosis'],
            'procedure': r['procedure'],
            'primarySurgeon': r['primary_surgeon'],
            'assistantSurgeons': r['assistant_surgeons'],
            'anesthesiaType': r['anesthesia_type'],
            'anesthesiologist': r['anesthesiologist'],
            'implants': r['implants'],
            'intraopFindings': r['intraop_findings'],
            'otNotes': r['ot_notes'],
            'complications': r['complications'],
            'postOpPlan': r['post_op_plan'],
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
      final models = await _ds.getSurgeriesForPatient(patientId);
      for (final m in models) {
        await _local.upsert(m.toFullJson());
      }
      state = models.map((m) => m.toEntity()).toList();
    } catch (_) {}
  }

  Future<void> refresh() => _syncFromApi(arg);

  Future<SurgeryEntity?> createSurgery({
    required String patientId,
    DateTime? date,
  }) async {
    try {
      final now = date ?? DateTime.now();
      final model = SurgeryModel(
        id: const Uuid().v4(),
        patientId: patientId,
        surgeryDate: now.toIso8601String(),
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );
      return _persistSurgery(model, isNew: true);
    } catch (_) {
      return null;
    }
  }

  Future<SurgeryEntity?> saveSurgery(SurgeryEntity surgery) async {
    final model = SurgeryModel.fromEntity(surgery);
    return _persistSurgery(model, isNew: false);
  }

  Future<SurgeryEntity?> _persistSurgery(SurgeryModel model,
      {required bool isNew}) async {
    // Always cache locally first (works on both web and mobile)
    await _local.upsert(model.toFullJson());

    if (_online) {
      try {
        final saved = isNew
            ? await _ds.createSurgery(model)
            : await _ds.updateSurgery(model);
        await _local.upsert(saved.toFullJson());
        final entity = saved.toEntity();
        if (isNew) {
          state = [entity, ...state];
        } else {
          state = state.map((s) => s.id == entity.id ? entity : s).toList();
        }
        return entity;
      } catch (e) {
        debugPrint('[SurgeryProvider] API error: $e');
        return null;
      }
    }

    // Offline: enqueue for sync when connection restores
    await _queue.enqueue(
      entityType: 'surgeries',
      entityId: model.id,
      operation: isNew ? 'insert' : 'update',
      payload: {...model.toFullJson(), 'patientId': model.patientId},
    );
    await _local.markPending(model.id);
    final pendingEntity = model.toEntity().copyWith(syncStatus: 'pending');
    if (isNew) {
      state = [pendingEntity, ...state];
    } else {
      state = state.map((s) => s.id == model.id ? pendingEntity : s).toList();
    }
    return pendingEntity;
  }

  Future<void> deleteSurgery(String id) async {
    if (_online) {
      try {
        await _ds.deleteSurgery('$arg/$id');
      } catch (_) {}
    } else {
      await _queue.enqueue(
        entityType: 'surgeries',
        entityId: id,
        operation: 'delete',
        payload: {'patientId': arg},
      );
    }
    await _local.delete(id);
    state = state.where((s) => s.id != id).toList();
  }
}

final surgeriesProvider =
    NotifierProviderFamily<SurgeriesNotifier, List<SurgeryEntity>, String>(
        SurgeriesNotifier.new);

// arg format: "patientId/surgeryId"
class SurgeryEditNotifier extends FamilyNotifier<SurgeryEntity?, String> {
  SurgerySupabaseDataSource get _ds => ref.read(surgeryDataSourceProvider);
  LocalSurgeryCache get _local => ref.read(localSurgeryCacheProvider);
  bool get _online => ref.read(isOnlineProvider);

  @override
  SurgeryEntity? build(String arg) {
    Future.microtask(() => _load(arg));
    return null;
  }

  Future<void> _load(String arg) async {
    final parts = arg.split('/');
    final surgeryId = parts.length > 1 ? parts[1] : parts[0];

    // Show cached data immediately
    final row = await _local.getById(surgeryId);
    if (row != null) {
      final js = row['data_json'] as String?;
      if (js != null) {
        state = SurgeryModel.fromJson(
                jsonDecode(js) as Map<String, dynamic>)
            .toEntity();
      }
    }

    // Refresh from API if online
    if (_online) {
      try {
        final model = await _ds.getSurgeryById(arg);
        await _local.upsert(model.toFullJson());
        state = model.toEntity();
      } catch (_) {}
    }
  }

  void update(SurgeryEntity updated) => state = updated;

  Future<bool> save() async {
    if (state == null) return false;
    final model = SurgeryModel.fromEntity(state!);
    await _local.upsert(model.toFullJson());

    if (_online) {
      try {
        final saved = await _ds.updateSurgery(model);
        await _local.upsert(saved.toFullJson());
        state = saved.toEntity();
        return true;
      } catch (e) {
        debugPrint('[SurgeryEditProvider] API error: $e');
        return false;
      }
    }

    await ref.read(offlineQueueProvider).enqueue(
      entityType: 'surgeries',
      entityId: model.id,
      operation: 'update',
      payload: {...model.toFullJson(), 'patientId': model.patientId},
    );
    return true;
  }
}

final surgeryEditProvider =
    NotifierProviderFamily<SurgeryEditNotifier, SurgeryEntity?, String>(
        SurgeryEditNotifier.new);
