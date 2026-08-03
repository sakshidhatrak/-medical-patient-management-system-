import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/patient_model.dart';

abstract interface class PatientSupabaseDataSource {
  Future<List<PatientModel>> getPatients({int page, int pageSize, String? search, String? filter});
  Future<PatientModel> getPatientById(String id);
  Future<PatientModel> createPatient(PatientModel patient);
  Future<PatientModel> updatePatient(PatientModel patient);
  Future<void> deletePatient(String id);
  Future<List<PatientModel>> searchDuplicates(String name, String? phone);
}

class PatientApiDataSourceImpl implements PatientSupabaseDataSource {
  final ApiClient _api;

  const PatientApiDataSourceImpl(this._api);

  @override
  Future<List<PatientModel>> getPatients({
    int page = 1,
    int pageSize = 20,
    String? search,
    String? filter,
  }) async {
    try {
      final data = await _api.get<List<PatientModel>>(
        '/patients',
        queryParameters: {
          'page': page,
          'size': pageSize,
          if (search != null && search.isNotEmpty) 'search': search,
        },
        fromJson: (json) {
          final envelope = (json as Map<String, dynamic>)['data'] as Map<String, dynamic>;
          final content = envelope['content'] as List<dynamic>;
          return content
              .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
      return data;
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'FETCH_ERROR');
    }
  }

  @override
  Future<PatientModel> getPatientById(String id) async {
    try {
      return await _api.get<PatientModel>(
        '/patients/$id',
        fromJson: (json) => PatientModel.fromJson(
          (json as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        ),
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'FETCH_ERROR');
    }
  }

  @override
  Future<PatientModel> createPatient(PatientModel patient) async {
    try {
      return await _api.post<PatientModel>(
        '/patients',
        data: patient.toApiJson(),
        fromJson: (json) => PatientModel.fromJson(
          (json as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        ),
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'CREATE_ERROR');
    }
  }

  @override
  Future<PatientModel> updatePatient(PatientModel patient) async {
    try {
      return await _api.put<PatientModel>(
        '/patients/${patient.id}',
        data: patient.toApiJson(),
        fromJson: (json) => PatientModel.fromJson(
          (json as Map<String, dynamic>)['data'] as Map<String, dynamic>,
        ),
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'UPDATE_ERROR');
    }
  }

  @override
  Future<void> deletePatient(String id) async {
    try {
      await _api.delete<void>('/patients/$id');
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'DELETE_ERROR');
    }
  }

  @override
  Future<List<PatientModel>> searchDuplicates(String name, String? phone) async {
    try {
      final data = await _api.get<List<PatientModel>>(
        '/patients/duplicates',
        queryParameters: {'name': name},
        fromJson: (json) {
          final list = (json as Map<String, dynamic>)['data'] as List<dynamic>;
          return list
              .map((e) => PatientModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
      return data;
    } catch (_) {
      return [];
    }
  }
}
