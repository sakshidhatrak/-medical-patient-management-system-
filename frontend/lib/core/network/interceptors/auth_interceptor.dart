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
    if (token != null) {
      // Proactively refresh if the token is already expired or expiring within 60 s.
      // This prevents flooding the backend with 401s from parallel requests all
      // sending the same expired token.
      if (_isExpiredOrExpiringSoon(token)) {
        final fresh = await _doRefresh();
        options.headers['Authorization'] = 'Bearer ${fresh ?? token}';
      } else {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);

    // A concurrent request queued before this one may have already refreshed the
    // token.  Check storage first to avoid a redundant re-login round-trip.
    final stored = await _storage.read(key: AppConfig.tokenKey);
    if (stored != null && !_isExpiredOrExpiringSoon(stored, bufferSeconds: 0)) {
      err.requestOptions.headers['Authorization'] = 'Bearer $stored';
      try {
        final retried = await _authDio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(retried);
      } catch (_) {
        return handler.next(err);
      }
    }

    // Token is still expired — perform re-login now.
    final newToken = await _doRefresh();
    if (newToken != null) {
      err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
      try {
        final retried = await _authDio.fetch<dynamic>(err.requestOptions);
        return handler.resolve(retried);
      } catch (_) {
        return handler.next(err);
      }
    }

    await _clearTokens();
    handler.next(err);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Re-login with stored credentials.  Returns the new token on success, null
  /// if credentials are missing or the login request fails.
  Future<String?> _doRefresh() async {
    try {
      final email = await _storage.read(key: AppConfig.credEmailKey);
      final pass  = await _storage.read(key: AppConfig.credPassKey);
      if (email == null || pass == null) return null;

      final resp = await _authDio.post<Map<String, dynamic>>(
        AppConfig.loginEndpoint,
        data: jsonEncode({'email': email, 'password': pass}),
      );

      final newToken = resp.data?['data']?['token'] as String?;
      if (newToken == null) return null;

      await _storage.write(key: AppConfig.tokenKey, value: newToken);
      await _storage.write(key: AppConfig.refreshTokenKey, value: newToken);
      return newToken;
    } catch (_) {
      return null;
    }
  }

  /// Decodes the JWT payload without verifying the signature and checks whether
  /// the token is already expired or will expire within [bufferSeconds].
  bool _isExpiredOrExpiringSoon(String token, {int bufferSeconds = 60}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;

      // Base64Url decode — add padding if needed.
      var payload = parts[1];
      final rem = payload.length % 4;
      if (rem != 0) payload += '=' * (4 - rem);

      final decoded = utf8.decode(base64Url.decode(payload));
      final claims  = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = claims['exp'];
      if (exp == null) return false;

      final expiry = DateTime.fromMillisecondsSinceEpoch(
          (exp as int) * 1000, isUtc: true);
      return DateTime.now().toUtc()
          .isAfter(expiry.subtract(Duration(seconds: bufferSeconds)));
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    await _storage.write(key: AppConfig.tokenKey, value: null);
    await _storage.write(key: AppConfig.refreshTokenKey, value: null);
  }
}
