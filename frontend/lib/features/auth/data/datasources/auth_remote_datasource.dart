import '../../../../core/error/exceptions.dart';
import '../models/user_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<({UserModel user, String token, String refreshToken})> login({
    required String email,
    required String password,
  });

  Future<void> logout();
}

// Dummy credentials for local development / demo
const _kDummyEmail = 'admin@test.com';
const _kDummyPassword = 'admin123';

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl();

  @override
  Future<({UserModel user, String token, String refreshToken})> login({
    required String email,
    required String password,
  }) async {
    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 800));

    if (email != _kDummyEmail || password != _kDummyPassword) {
      throw const UnauthorizedException(
        'Invalid email or password.',
        code: 'INVALID_CREDENTIALS',
      );
    }

    final user = UserModel(
      id: 'admin-001',
      email: _kDummyEmail,
      firstName: 'Admin',
      lastName: 'User',
      role: 'admin',
      createdAt: DateTime(2024, 1, 1).toIso8601String(),
    );

    return (
      user: user,
      token: 'dummy-access-token-admin-001',
      refreshToken: 'dummy-refresh-token-admin-001',
    );
  }

  @override
  Future<void> logout() async {
    // No-op for dummy implementation
  }
}
