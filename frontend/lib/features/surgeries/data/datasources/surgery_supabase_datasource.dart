import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/exceptions.dart';
import '../models/surgery_model.dart';

abstract interface class SurgerySupabaseDataSource {
  Future<List<SurgeryModel>> getSurgeriesForPatient(String patientId);
  Future<SurgeryModel> getSurgeryById(String id);
  Future<SurgeryModel> createSurgery(SurgeryModel surgery);
  Future<SurgeryModel> updateSurgery(SurgeryModel surgery);
  Future<void> deleteSurgery(String id);
}

class SurgerySupabaseDataSourceImpl implements SurgerySupabaseDataSource {
  final sb.SupabaseClient _client;
  const SurgerySupabaseDataSourceImpl(this._client);

  static const _table = 'surgeries';

  @override
  Future<List<SurgeryModel>> getSurgeriesForPatient(String patientId) async {
    try {
      final data = await _client
          .from(_table)
          .select()
          .eq('patient_id', patientId)
          .eq('is_active', true)
          .order('surgery_date', ascending: false);
      return (data as List)
          .map((e) => SurgeryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<SurgeryModel> getSurgeryById(String id) async {
    try {
      final data =
          await _client.from(_table).select().eq('id', id).single();
      return SurgeryModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Surgery not found.', code: 'NOT_FOUND');
      }
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<SurgeryModel> createSurgery(SurgeryModel surgery) async {
    try {
      final data = await _client
          .from(_table)
          .insert(surgery.toSupabaseJson())
          .select()
          .single();
      return SurgeryModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'CREATE_ERROR');
    }
  }

  @override
  Future<SurgeryModel> updateSurgery(SurgeryModel surgery) async {
    try {
      final payload = surgery.toSupabaseJson()
        ..remove('id')
        ..remove('patient_id');
      final data = await _client
          .from(_table)
          .update(payload)
          .eq('id', surgery.id)
          .select()
          .single();
      return SurgeryModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'UPDATE_ERROR');
    }
  }

  @override
  Future<void> deleteSurgery(String id) async {
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
