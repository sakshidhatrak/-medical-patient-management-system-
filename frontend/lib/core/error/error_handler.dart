import 'package:dio/dio.dart';

import 'exceptions.dart';
import 'failures.dart';

class ErrorHandler {
  static AppException fromDioException(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        const NetworkException(
          'Connection timed out. Please check your internet connection.',
          code: 'TIMEOUT',
        ),
      DioExceptionType.connectionError => const NetworkException(
          'No internet connection. Please check your network.',
          code: 'NO_CONNECTION',
        ),
      DioExceptionType.badResponse => _fromResponse(e.response),
      DioExceptionType.cancel =>
        const NetworkException('Request cancelled.', code: 'CANCELLED'),
      _ => const NetworkException(
          'An unexpected network error occurred.',
          code: 'UNKNOWN_NETWORK',
        ),
    };
  }

  static AppException _fromResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;
    final message = _extractMessage(data);

    return switch (statusCode) {
      400 => ServerException(message, code: 'BAD_REQUEST', statusCode: statusCode),
      401 => UnauthorizedException(message, code: 'UNAUTHORIZED'),
      403 => AuthException(message, code: 'FORBIDDEN'),
      404 => NotFoundException(message, code: 'NOT_FOUND'),
      422 => ValidationException(
          message,
          code: 'VALIDATION_ERROR',
          fieldErrors: _extractFieldErrors(data),
        ),
      500 => ServerException(message, code: 'SERVER_ERROR', statusCode: statusCode),
      503 => ServerException(
          'Service temporarily unavailable.',
          code: 'SERVICE_UNAVAILABLE',
          statusCode: statusCode,
        ),
      _ => ServerException(message, code: 'UNKNOWN', statusCode: statusCode),
    };
  }

  static String _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message'] as String? ??
          data['error'] as String? ??
          'An error occurred.';
    }
    return 'An error occurred.';
  }

  static Map<String, List<String>>? _extractFieldErrors(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final errors = data['errors'];
    if (errors is! Map<String, dynamic>) return null;
    return errors.map((key, value) {
      final list = value is List
          ? value.map((e) => e.toString()).toList()
          : [value.toString()];
      return MapEntry(key, list);
    });
  }

  static Failure toFailure(AppException exception) {
    if (exception is ServerException) {
      return ServerFailure(exception.message,
          code: exception.code, statusCode: exception.statusCode);
    }
    if (exception is NetworkException) {
      return NetworkFailure(exception.message, code: exception.code);
    }
    if (exception is CacheException) {
      return CacheFailure(exception.message, code: exception.code);
    }
    if (exception is AuthException || exception is UnauthorizedException) {
      return AuthFailure(exception.message, code: exception.code);
    }
    if (exception is ValidationException) {
      return ValidationFailure(exception.message,
          code: exception.code, fieldErrors: exception.fieldErrors);
    }
    if (exception is NotFoundException) {
      return NotFoundFailure(exception.message, code: exception.code);
    }
    return UnknownFailure(exception.message, code: exception.code);
  }
}
