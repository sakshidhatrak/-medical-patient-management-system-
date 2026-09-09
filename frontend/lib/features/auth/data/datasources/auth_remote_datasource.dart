import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../../core/config/env_config.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<(UserModel, String)> login({required String email, required String password});
  Future<void> logout();
}

class AuthSpringDataSourceImpl implements AuthRemoteDataSource {
  late final Dio _dio;

  AuthSpringDataSourceImpl() {
    _dio = Dio(BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      connectTimeout: const Duration(milliseconds: EnvConfig.connectTimeout),
      receiveTimeout: const Duration(milliseconds: EnvConfig.receiveTimeout),
      contentType: 'application/json; charset=utf-8',
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
    ));
  }

  static const _maxRetries = 3;
  static const _retryDelay = Duration(seconds: 5);

  bool _isRetryable(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      (e.response?.statusCode != null && e.response!.statusCode! >= 500);

  @override
  Future<(UserModel, String)> login({
    required String email,
    required String password,
  }) async {
    DioException? lastError;

    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/auth/login',
          data: jsonEncode({'email': email.trim().toLowerCase(), 'password': password}),
        );
        final data = response.data?['data'] as Map<String, dynamic>?;
        if (data == null) {
          throw const UnauthorizedException('Login failed.', code: 'LOGIN_FAILED');
        }
        final token = data['token'] as String;
        final userJson = data['user'] as Map<String, dynamic>;
        return (UserModel.fromJson(userJson), token);
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (status == 400 || status == 401) {
          final errMsg = e.response?.data?['error'] as String? ??
              e.response?.data?['message'] as String? ??
              'Incorrect email or password.';
          throw UnauthorizedException(errMsg, code: 'INVALID_CREDENTIALS');
        }
        if (_isRetryable(e) && attempt < _maxRetries) {
          lastError = e;
          await Future.delayed(_retryDelay);
          continue;
        }
        lastError = e;
        break;
      } catch (e) {
        if (e is AppException) rethrow;
        throw ServerException(e.toString(), code: 'LOGIN_FAILED');
      }
    }

    // All retries exhausted
    final status = lastError?.response?.statusCode;
    if (status == null ||
        lastError?.type == DioExceptionType.connectionError ||
        lastError?.type == DioExceptionType.connectionTimeout ||
        lastError?.type == DioExceptionType.receiveTimeout) {
      throw const ServerException(
          'Cannot connect to server. Please check your internet connection and try again.',
          code: 'SERVER_UNREACHABLE');
    }
    throw ServerException(
        lastError?.response?.data?['message'] as String? ?? 'Network error',
        code: 'NETWORK_ERROR');
  }

  @override
  Future<void> logout() async {
    // Spring Boot uses stateless JWT — nothing to invalidate remotely.
  }
}
