abstract class AppException implements Exception {
  final String message;
  final String? code;

  const AppException(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message (code: $code)';
}

class ServerException extends AppException {
  final int? statusCode;
  const ServerException(super.message, {super.code, this.statusCode});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code});
}

class CacheException extends AppException {
  const CacheException(super.message, {super.code});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, {super.code});
}

class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;
  const ValidationException(super.message, {super.code, this.fieldErrors});
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.code});
}
