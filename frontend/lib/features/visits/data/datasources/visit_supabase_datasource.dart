import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../models/visit_model.dart';

abstract interface class VisitSupabaseDataSource {
  Future<List<VisitModel>> getVisitsForPatient(String patientId);
  Future<VisitModel> getVisitById(String id);
  Future<VisitModel> createVisit(VisitModel visit);
  Future<VisitModel> updateVisit(VisitModel visit);
  Future<void> deleteVisit(String id);
}

class VisitApiDataSourceImpl implements VisitSupabaseDataSource {
  final ApiClient _api;
  const VisitApiDataSourceImpl(this._api);

  @override
  Future<List<VisitModel>> getVisitsForPatient(String patientId) async {
    try {
      return await _api.get<List<VisitModel>>(
        '/patients/$patientId/visits',
        fromJson: (json) {
          final list = (json as Map<String, dynamic>)['data'] as List<dynamic>;
          return list
              .map((e) => VisitModel.fromJson(e as Map<String, dynamic>))
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
  Future<VisitModel> getVisitById(String id) async {
    // visitId alone isn't enough — caller must pass patientId/visitId.
    // The provider always calls with full context; we encode both in id as "patientId/visitId".
    final parts = id.split('/');
    final patientId = parts[0];
    final visitId = parts.length > 1 ? parts[1] : parts[0];
    try {
      return await _api.get<VisitModel>(
        '/patients/$patientId/visits/$visitId',
        fromJson: (json) => VisitModel.fromJson(
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
  Future<VisitModel> createVisit(VisitModel visit) async {
    try {
      return await _api.post<VisitModel>(
        '/patients/${visit.patientId}/visits',
        data: visit.toApiJson(),
        fromJson: (json) => VisitModel.fromJson(
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
  Future<VisitModel> updateVisit(VisitModel visit) async {
    try {
      return await _api.put<VisitModel>(
        '/patients/${visit.patientId}/visits/${visit.id}',
        data: visit.toApiJson(),
        fromJson: (json) => VisitModel.fromJson(
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
  Future<void> deleteVisit(String id) async {
    // id is "patientId/visitId"
    final parts = id.split('/');
    final patientId = parts[0];
    final visitId = parts.length > 1 ? parts[1] : parts[0];
    try {
      await _api.delete<void>('/patients/$patientId/visits/$visitId');
    } on AppException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), code: 'DELETE_ERROR');
    }
  }
}
