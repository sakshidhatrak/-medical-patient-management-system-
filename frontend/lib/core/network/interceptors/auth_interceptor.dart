import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../config/env_config.dart';
import '../../storage/storage_service.dart';

class AuthInterceptor extends QueuedInterceptorsWrapper {
  final StorageService _storage;

  // Separate Dio instance used only for token refresh (avoids circular interceptor chain)
  late final Dio _refreshDio;

  AuthInterceptor(this._storage) {
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    try {
      final refreshToken =
          await _storage.read(key: AppConfig.refreshTokenKey);
      if (refreshToken == null) {
        await _clearTokens();
        return handler.next(err);
      }

      final response = await _refreshDio.post(
        AppConfig.refreshEndpoint,
        data: {'refresh_token': refreshToken},
      );

      final newToken = response.data['access_token'] as String;
      final newRefresh = response.data['refresh_token'] as String?;

      await _storage.write(key: AppConfig.tokenKey, value: newToken);
      if (newRefresh != null) {
        await _storage.write(key: AppConfig.refreshTokenKey, value: newRefresh);
      }

      // Retry the original request with the new token
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      final retried = await _refreshDio.fetch<dynamic>(err.requestOptions);
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
