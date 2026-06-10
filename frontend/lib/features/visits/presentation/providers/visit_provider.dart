import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../data/datasources/visit_supabase_datasource.dart';
import '../../data/models/visit_model.dart';
import '../../domain/entities/visit_entity.dart';

final _supabaseProvider = Provider((_) => sb.Supabase.instance.client);

final visitDataSourceProvider = Provider<VisitSupabaseDataSource>((ref) =>
    VisitSupabaseDataSourceImpl(ref.watch(_supabaseProvider)));

// ── Per-patient visits ────────────────────────────────────────────

class VisitsNotifier extends FamilyNotifier<List<VisitEntity>, String> {
  VisitSupabaseDataSource get _ds => ref.read(visitDataSourceProvider);

  @override
  List<VisitEntity> build(String arg) {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final models = await _ds.getVisitsForPatient(arg);
      state = models.map((m) => m.toEntity()).toList();
    } catch (_) {}
  }

  void refresh() => _load();

  Future<VisitEntity?> createVisit({
    required String patientId,
    VisitType type = VisitType.opd,
  }) async {
    try {
      final now = DateTime.now();
      final model = VisitModel(
        id: const Uuid().v4(),
        patientId: patientId,
        visitDate: now.toIso8601String(),
        visitType: type.value,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      );
      final saved = await _ds.createVisit(model);
      final entity = saved.toEntity();
      state = [entity, ...state];
      return entity;
    } catch (_) {
      return null;
    }
  }

  Future<VisitEntity?> saveVisit(VisitEntity visit) async {
    try {
      final model = VisitModel.fromEntity(visit);
      final saved = await _ds.updateVisit(model);
      final entity = saved.toEntity();
      state = state.map((v) => v.id == entity.id ? entity : v).toList();
      return entity;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteVisit(String id) async {
    await _ds.deleteVisit(id);
    state = state.where((v) => v.id != id).toList();
  }
}

final visitsProvider =
    NotifierProviderFamily<VisitsNotifier, List<VisitEntity>, String>(
        VisitsNotifier.new);

// ── Single visit editing ──────────────────────────────────────────

class VisitEditNotifier extends FamilyNotifier<VisitEntity?, String> {
  VisitSupabaseDataSource get _ds => ref.read(visitDataSourceProvider);

  @override
  VisitEntity? build(String visitId) {
    _load(visitId);
    return null;
  }

  Future<void> _load(String visitId) async {
    try {
      final model = await _ds.getVisitById(visitId);
      state = model.toEntity();
    } catch (_) {}
  }

  void update(VisitEntity updated) => state = updated;

  Future<bool> save() async {
    if (state == null) return false;
    try {
      final model = VisitModel.fromEntity(state!);
      final saved = await _ds.updateVisit(model);
      state = saved.toEntity();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final visitEditProvider =
    NotifierProviderFamily<VisitEditNotifier, VisitEntity?, String>(
        VisitEditNotifier.new);
