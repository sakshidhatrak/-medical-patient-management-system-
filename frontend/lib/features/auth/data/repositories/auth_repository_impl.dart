import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';

// Dummy credentials — replace with real API integration later
const _kDummyEmail = 'admin@test.com';
const _kDummyPassword = 'admin123';

const _kDummyUser = UserModel(
  id: 'admin-001',
  email: _kDummyEmail,
  firstName: 'Admin',
  lastName: 'User',
  role: 'admin',
  createdAt: '2024-01-01T00:00:00.000Z',
);

class AuthRepositoryImpl implements AuthRepository {
  final AuthLocalDataSource _local;

  AuthRepositoryImpl({required AuthLocalDataSource local}) : _local = local;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Simulate auth latency
      await Future.delayed(const Duration(milliseconds: 800));

      if (email != _kDummyEmail || password != _kDummyPassword) {
        return const Left(
          AuthFailure('Invalid email or password.', code: 'INVALID_CREDENTIALS'),
        );
      }

      await Future.wait([
        _local.saveToken(
          token: 'dummy-access-token-admin-001',
          refreshToken: 'dummy-refresh-token-admin-001',
        ),
        _local.saveUser(_kDummyUser),
      ]);

      return Right(_kDummyUser.toEntity());
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _local.clearAll();
      return const Right(null);
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final userModel = await _local.getUser();
      return Right(userModel?.toEntity());
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshSession() async {
    try {
      final userModel = await _local.getUser();
      if (userModel == null) {
        return const Left(AuthFailure('No cached session.', code: 'NO_SESSION'));
      }
      return Right(userModel.toEntity());
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }
}
