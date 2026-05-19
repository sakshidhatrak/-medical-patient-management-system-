import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env_config.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

class DioFactory {
  static Dio create(FlutterSecureStorage secureStorage) {
    final dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: EnvConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: EnvConfig.receiveTimeout),
        sendTimeout: const Duration(milliseconds: EnvConfig.sendTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (EnvConfig.apiKey.isNotEmpty) 'X-API-Key': EnvConfig.apiKey,
        },
      ),
    );

    // Order matters: log → auth → error
    if (EnvConfig.isDevelopment) {
      dio.interceptors.add(LoggingInterceptor());
    }
    dio.interceptors.add(AuthInterceptor(secureStorage));
    dio.interceptors.add(ErrorInterceptor());

    return dio;
  }
}
