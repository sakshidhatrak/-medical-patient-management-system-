import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/surgery_model.dart';

abstract interface class SurgerySupabaseDataSource {
  Future<List<SurgeryModel>> getSurgeriesForPatient(String patientId);
  Future<SurgeryModel> getSurgeryById(String id);
  Future<SurgeryModel> createSurgery(SurgeryModel surgery);
  Future<SurgeryModel> updateSurgery(SurgeryModel surgery);
  Future<void> deleteSurgery(String id);
}

class SurgeryApiDataSourceImpl implements SurgerySupabaseDataSource {
  final ApiClient _api;
  const SurgeryApiDataSourceImpl(this._api);

  @override
  Future<List<SurgeryModel>> getSurgeriesForPatient(String patientId) async {
    try {
      return await _api.get<List<SurgeryModel>>(
        '/patients/$patientId/surgeries',
        fromJson: (json) {
          final list = (json as Map<String, dynamic>)['data'] as List<dynamic>;
          return list
              .map((e) => SurgeryModel.fromJson(e as Map<String, dynamic>))
              .toList();
        },
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'FETCH_ERROR');
    }
  }

  @override
  Future<SurgeryModel> getSurgeryById(String id) async {
    // id is "patientId/surgeryId"
    final parts = id.split('/');
    final patientId = parts[0];
    final surgeryId = parts.length > 1 ? parts[1] : parts[0];
    try {
      return await _api.get<SurgeryModel>(
        '/patients/$patientId/surgeries/$surgeryId',
        fromJson: (json) => SurgeryModel.fromJson(
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
  Future<SurgeryModel> createSurgery(SurgeryModel surgery) async {
    try {
      return await _api.post<SurgeryModel>(
        '/patients/${surgery.patientId}/surgeries',
        data: surgery.toApiJson(),
        fromJson: (json) => SurgeryModel.fromJson(
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
  Future<SurgeryModel> updateSurgery(SurgeryModel surgery) async {
    try {
      return await _api.put<SurgeryModel>(
        '/patients/${surgery.patientId}/surgeries/${surgery.id}',
        data: surgery.toApiJson(),
        fromJson: (json) => SurgeryModel.fromJson(
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
  Future<void> deleteSurgery(String id) async {
    // id is "patientId/surgeryId"
    final parts = id.split('/');
    final patientId = parts[0];
    final surgeryId = parts.length > 1 ? parts[1] : parts[0];
    try {
      await _api.delete<void>('/patients/$patientId/surgeries/$surgeryId');
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'DELETE_ERROR');
    }
  }
}
