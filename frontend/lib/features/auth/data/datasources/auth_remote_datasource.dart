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
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
  }

  @override
  Future<(UserModel, String)> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw const UnauthorizedException('Login failed.', code: 'LOGIN_FAILED');
      }
      final token = data['token'] as String;
      final userJson = data['user'] as Map<String, dynamic>;
      return (UserModel.fromJson(userJson), token);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw const UnauthorizedException(
            'Incorrect email or password.', code: 'INVALID_CREDENTIALS');
      }
      throw ServerException(
          e.message ?? 'Network error', code: 'NETWORK_ERROR');
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'LOGIN_FAILED');
    }
  }

  @override
  Future<void> logout() async {
    // Spring Boot uses stateless JWT — nothing to invalidate remotely.
  }
}
