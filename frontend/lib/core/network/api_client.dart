import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../error/error_handler.dart';
import '../error/exceptions.dart';
import 'dio_factory.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final dio = DioFactory.create(secureStorage);
  return ApiClient(dio);
});

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) =>
      _request(
        () => _dio.get<dynamic>(path,
            queryParameters: queryParameters, options: options),
        fromJson: fromJson,
      );

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) =>
      _request(
        () => _dio.post<dynamic>(path,
            data: data, queryParameters: queryParameters, options: options),
        fromJson: fromJson,
      );

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) =>
      _request(
        () => _dio.put<dynamic>(path,
            data: data, queryParameters: queryParameters, options: options),
        fromJson: fromJson,
      );

  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) =>
      _request(
        () => _dio.patch<dynamic>(path,
            data: data, queryParameters: queryParameters, options: options),
        fromJson: fromJson,
      );

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic json)? fromJson,
  }) =>
      _request(
        () => _dio.delete<dynamic>(path,
            data: data, queryParameters: queryParameters, options: options),
        fromJson: fromJson,
      );

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() call, {
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final response = await call();
      if (fromJson != null) return fromJson(response.data);
      return response.data as T;
    } on DioException catch (e) {
      // ErrorInterceptor already wraps the error; re-throw as AppException
      final appException = e.error is AppException
          ? e.error as AppException
          : ErrorHandler.fromDioException(e);
      throw appException;
    }
  }
}
