import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/use_case.dart';
import '../entities/patient_entity.dart';
import '../repositories/patient_repository.dart';

class CreatePatientUseCase implements UseCase<PatientEntity, PatientEntity> {
  final PatientRepository _repository;

  CreatePatientUseCase(this._repository);

  @override
  Future<Either<Failure, PatientEntity>> call(PatientEntity params) {
    return _repository.createPatient(params);
  }
}
