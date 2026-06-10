import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../data/datasources/surgery_supabase_datasource.dart';
import '../../data/models/surgery_model.dart';
import '../../domain/entities/surgery_entity.dart';

final _supabaseProvider = Provider((_) => sb.Supabase.instance.client);

final surgeryDataSourceProvider = Provider<SurgerySupabaseDataSource>((ref) =>
    SurgerySupabaseDataSourceImpl(ref.watch(_supabaseProvider)));

class SurgeriesNotifier extends FamilyNotifier<List<SurgeryEntity>, String> {
  SurgerySupabaseDataSource get _ds => ref.read(surgeryDataSourceProvider);

  @override
  List<SurgeryEntity> build(String arg) {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final models = await _ds.getSurgeriesForPatient(arg);
      state = models.map((m) => m.toEntity()).toList();
    } catch (_) {}
  }

  void refresh() => _load();

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
      final saved = await _ds.createSurgery(model);
      final entity = saved.toEntity();
      state = [entity, ...state];
      return entity;
    } catch (_) {
      return null;
    }
  }

  Future<SurgeryEntity?> saveSurgery(SurgeryEntity surgery) async {
    try {
      final model = SurgeryModel.fromEntity(surgery);
      final saved = await _ds.updateSurgery(model);
      final entity = saved.toEntity();
      state = state.map((s) => s.id == entity.id ? entity : s).toList();
      return entity;
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteSurgery(String id) async {
    await _ds.deleteSurgery(id);
    state = state.where((s) => s.id != id).toList();
  }
}

final surgeriesProvider =
    NotifierProviderFamily<SurgeriesNotifier, List<SurgeryEntity>, String>(
        SurgeriesNotifier.new);

class SurgeryEditNotifier extends FamilyNotifier<SurgeryEntity?, String> {
  SurgerySupabaseDataSource get _ds => ref.read(surgeryDataSourceProvider);

  @override
  SurgeryEntity? build(String surgeryId) {
    _load(surgeryId);
    return null;
  }

  Future<void> _load(String id) async {
    try {
      final model = await _ds.getSurgeryById(id);
      state = model.toEntity();
    } catch (_) {}
  }

  void update(SurgeryEntity updated) => state = updated;

  Future<bool> save() async {
    if (state == null) return false;
    try {
      final saved = await _ds.updateSurgery(SurgeryModel.fromEntity(state!));
      state = saved.toEntity();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final surgeryEditProvider =
    NotifierProviderFamily<SurgeryEditNotifier, SurgeryEntity?, String>(
        SurgeryEditNotifier.new);
