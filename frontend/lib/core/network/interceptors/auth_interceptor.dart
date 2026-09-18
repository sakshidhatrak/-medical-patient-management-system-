import 'dart:convert';

import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../config/env_config.dart';
import '../../storage/storage_service.dart';

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final StorageService _storage;

  // Separate Dio instance used only for re-login (avoids circular interceptor chain)
  late final Dio _authDio;

  AuthInterceptor(this._storage) {
    _authDio = Dio(BaseOptions(
      baseUrl: EnvConfig.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);

    // Token expired — try silent re-login with stored credentials
    try {
      final email = await _storage.read(key: AppConfig.credEmailKey);
      final pass  = await _storage.read(key: AppConfig.credPassKey);

      if (email == null || pass == null) {
        await _clearTokens();
        return handler.next(err);
      }

      final resp = await _authDio.post<Map<String, dynamic>>(
        AppConfig.loginEndpoint,
        data: jsonEncode({'email': email, 'password': pass}),
      );

      final newToken = resp.data?['data']?['token'] as String?;
      if (newToken == null) {
        await _clearTokens();
        return handler.next(err);
      }

      await _storage.write(key: AppConfig.tokenKey, value: newToken);
      await _storage.write(key: AppConfig.refreshTokenKey, value: newToken);

      // Retry original request with new token
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retried = await _authDio.fetch<dynamic>(err.requestOptions);
      return handler.resolve(retried);
    } catch (_) {
      await _clearTokens();
      handler.next(err);
    }
  }

  Future<void> _clearTokens() async {
    await _storage.write(key: AppConfig.tokenKey, value: null);
    await _storage.write(key: AppConfig.refreshTokenKey, value: null);
  }
}
