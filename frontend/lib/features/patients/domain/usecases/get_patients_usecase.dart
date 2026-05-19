import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/use_case.dart';
import '../entities/patient_entity.dart';
import '../repositories/patient_repository.dart';

class GetPatientsParams extends Equatable {
  final int page;
  final int pageSize;
  final String? search;

  const GetPatientsParams({
    required this.page,
    this.pageSize = AppConfig.pageSize,
    this.search,
  });

  @override
  List<Object?> get props => [page, pageSize, search];
}

class GetPatientsUseCase
    implements UseCase<List<PatientEntity>, GetPatientsParams> {
  final PatientRepository _repository;

  GetPatientsUseCase(this._repository);

  @override
  Future<Either<Failure, List<PatientEntity>>> call(
      GetPatientsParams params) {
    return _repository.getPatients(
      page: params.page,
      pageSize: params.pageSize,
      search: params.search,
    );
  }
}
