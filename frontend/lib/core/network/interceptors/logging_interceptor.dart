import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌── REQUEST ─────────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('│ Query: ${options.queryParameters}');
    }
    if (options.data != null) {
      debugPrint('│ Body: ${options.data}');
    }
    debugPrint('└────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('┌── RESPONSE ────────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('│ Body: ${response.data}');
    debugPrint('└────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌── ERROR ───────────────────────────────────');
    debugPrint('│ ${err.requestOptions.method} ${err.requestOptions.uri}');
    debugPrint('│ Type: ${err.type}');
    debugPrint('│ Message: ${err.message}');
    if (err.response != null) {
      debugPrint('│ Status: ${err.response?.statusCode}');
      debugPrint('│ Data: ${err.response?.data}');
    }
    debugPrint('└────────────────────────────────────────────');
    handler.next(err);
  }
}
