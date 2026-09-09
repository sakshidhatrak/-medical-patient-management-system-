import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

String _hashCreds(String email, String password) =>
    sha256.convert(utf8.encode('${email.trim().toLowerCase()}:$password')).toString();

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  const AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required AuthLocalDataSource local,
  })  : _remote = remote,
        _local = local;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final (user, token) =
          await _remote.login(email: email, password: password);
      await Future.wait([
        _local.saveUser(user),
        _local.saveToken(token: token, refreshToken: token),
        _local.saveCredHash(_hashCreds(email, password)),
      ]);
      return Right(user.toEntity());
    } on UnauthorizedException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    } on AppException catch (e) {
      // Server unreachable — try offline login with cached credentials
      final cachedUser = await _local.getUser();
      final storedHash = await _local.getCredHash();
      if (cachedUser != null &&
          storedHash != null &&
          storedHash == _hashCreds(email, password)) {
        return Right(cachedUser.toEntity());
      }
      return Left(ServerFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await Future.wait([_remote.logout(), _local.clearAll()]);
      return const Right(null);
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final cached = await _local.getUser();
      return Right(cached?.toEntity());
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> refreshSession() async {
    try {
      final cached = await _local.getUser();
      if (cached != null) return Right(cached.toEntity());
      return const Left(AuthFailure('No active session.', code: 'NO_SESSION'));
    } on AppException catch (e) {
      return Left(AuthFailure(e.message, code: e.code));
    }
  }
}
