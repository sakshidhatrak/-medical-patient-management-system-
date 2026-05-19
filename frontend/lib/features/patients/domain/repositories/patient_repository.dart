import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/patient_entity.dart';

abstract interface class PatientRepository {
  Future<Either<Failure, List<PatientEntity>>> getPatients({
    required int page,
    required int pageSize,
    String? search,
  });

  Future<Either<Failure, PatientEntity>> getPatientById(String id);

  Future<Either<Failure, PatientEntity>> createPatient(
      PatientEntity patient);

  Future<Either<Failure, PatientEntity>> updatePatient(
      PatientEntity patient);

  Future<Either<Failure, void>> deletePatient(String id);
}
