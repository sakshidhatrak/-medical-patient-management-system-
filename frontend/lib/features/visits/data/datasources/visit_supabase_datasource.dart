import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exceptions.dart';
import '../models/visit_model.dart';

abstract interface class VisitSupabaseDataSource {
  Future<List<VisitModel>> getVisitsForPatient(String patientId);
  Future<VisitModel> getVisitById(String id);
  Future<VisitModel> createVisit(VisitModel visit);
  Future<VisitModel> updateVisit(VisitModel visit);
  Future<void> deleteVisit(String id);
}

class VisitSupabaseDataSourceImpl implements VisitSupabaseDataSource {
  final sb.SupabaseClient _client;
  const VisitSupabaseDataSourceImpl(this._client);

  static const _table = 'visits';

  @override
  Future<List<VisitModel>> getVisitsForPatient(String patientId) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true)
          .order('visit_date', ascending: false);
      return (data as List)
          .map((e) => VisitModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<VisitModel> getVisitById(String id) async {
    try {
      final data =
          await _client.from(_table).select().eq('id', id).single();
      return VisitModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Visit not found.', code: 'NOT_FOUND');
      }
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<VisitModel> createVisit(VisitModel visit) async {
    try {
      final data = await _client
          .from(_table)
          .insert(visit.toSupabaseJson())
          .select()
          .single();
      return VisitModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'CREATE_ERROR');
    }
  }

  @override
  Future<VisitModel> updateVisit(VisitModel visit) async {
    try {
      final payload = visit.toSupabaseJson()
        ..remove('id')
        ..remove('patient_id');
      final data = await _client
          .from(_table)
          .update(payload)
          .eq('id', visit.id)
          .select()
          .single();
      return VisitModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'UPDATE_ERROR');
    }
  }

  @override
  Future<void> deleteVisit(String id) async {
    try {
      await _client.from(_table).update({
        'is_active': false,
        'deleted_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'DELETE_ERROR');
    }
  }
}
