import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_remote_datasource.dart';
import '../models/patient_model.dart';

class PatientRepositoryImpl implements PatientRepository {
  final PatientRemoteDataSource _remote;

  PatientRepositoryImpl({required PatientRemoteDataSource remote})
      : _remote = remote;

  @override
  Future<Either<Failure, List<PatientEntity>>> getPatients({
    required int page,
    required int pageSize,
    String? search,
  }) async {
    try {
      final models = await _remote.getPatients(
        page: page,
        pageSize: pageSize,
        search: search,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    }
  }

  @override
  Future<Either<Failure, PatientEntity>> getPatientById(String id) async {
    try {
      final model = await _remote.getPatientById(id);
      return Right(model.toEntity());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    }
  }

  @override
  Future<Either<Failure, PatientEntity>> createPatient(
      PatientEntity patient) async {
    try {
      final model = await _remote.createPatient(PatientModel.fromEntity(patient));
      return Right(model.toEntity());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    }
  }

  @override
  Future<Either<Failure, PatientEntity>> updatePatient(
      PatientEntity patient) async {
    try {
      final model = await _remote.updatePatient(PatientModel.fromEntity(patient));
      return Right(model.toEntity());
    } on AppException catch (e) {
      return Left(_toFailure(e));
    }
  }

  @override
  Future<Either<Failure, void>> deletePatient(String id) async {
    try {
      await _remote.deletePatient(id);
      return const Right(null);
    } on AppException catch (e) {
      return Left(_toFailure(e));
    }
  }

  static Failure _toFailure(AppException e) {
    if (e is NotFoundException) return NotFoundFailure(e.message, code: e.code);
    return ServerFailure(e.message, code: e.code);
  }
}
