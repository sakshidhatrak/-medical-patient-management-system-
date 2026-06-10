import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/patient_entity.dart';
import '../models/patient_model.dart';

abstract interface class PatientSupabaseDataSource {
  Future<List<PatientModel>> getPatients({int page, int pageSize, String? search, String? filter});
  Future<PatientModel> getPatientById(String id);
  Future<PatientModel> createPatient(PatientModel patient);
  Future<PatientModel> updatePatient(PatientModel patient);
  Future<void> deletePatient(String id);
  Future<List<PatientModel>> searchDuplicates(String name, String? phone);
}

class PatientSupabaseDataSourceImpl implements PatientSupabaseDataSource {
  final sb.SupabaseClient _client;

  const PatientSupabaseDataSourceImpl(this._client);

  static const _table = 'patients';

  @override
  Future<List<PatientModel>> getPatients({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? filter,
  }) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .eq('is_active', true);

      if (search != null && search.isNotEmpty) {
        query = query.or(
          'first_name.ilike.%$search%,last_name.ilike.%$search%,prn.eq.$search,phone.ilike.%$search%',
        );
      }

      final data = await query
          .order('created_at', ascending: false)
          .range((page - 1) * pageSize, page * pageSize - 1);

      return (data as List)
          .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<PatientModel> getPatientById(String id) async {
    try {
      final data = await _client.from(_table).select().eq('id', id).single();
      return PatientModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      if (e.code == 'PGRST116') {
        throw NotFoundException('Patient not found.', code: 'NOT_FOUND');
      }
      throw ServerException(e.message, code: 'FETCH_ERROR');
    }
  }

  @override
  Future<PatientModel> createPatient(PatientModel patient) async {
    try {
      final payload = patient.toSupabaseJson();
      final data = await _client.from(_table).insert(payload).select().single();
      return PatientModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'CREATE_ERROR');
    }
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    try {
      final payload = patient.toSupabaseJson()..remove('created_at');
      final data = await _client
          .from(_table)
          .update(payload)
          .eq('id', patient.id)
          .select()
          .single();
      return PatientModel.fromJson(data as Map<String, dynamic>);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'UPDATE_ERROR');
    }
  }

  @override
  Future<void> deletePatient(String id) async {
    try {
      await _client
          .from(_table)
          .update({'is_active': false, 'deleted_at': DateTime.now().toIso8601String()})
          .eq('id', id);
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'DELETE_ERROR');
    }
  }

  @override
  Future<List<PatientModel>> searchDuplicates(
      String name, String? phone) async {
    try {
      var query = _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .ilike('first_name', '%$name%');

      if (phone != null && phone.isNotEmpty) {
        query = query.ilike('phone', '%$phone%');
      }

      final data = await query.limit(5);
      return (data as List)
          .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on sb.PostgrestException catch (e) {
      throw ServerException(e.message, code: 'SEARCH_ERROR');
    }
  }
}
