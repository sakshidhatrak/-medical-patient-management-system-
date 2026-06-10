import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/core/error/exceptions.dart';
import 'package:medical_patient_management/core/error/failures.dart';
import 'package:medical_patient_management/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:medical_patient_management/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:medical_patient_management/features/auth/data/models/user_model.dart';
import 'package:medical_patient_management/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:medical_patient_management/core/storage/storage_service.dart';

void main() {
  late AuthRepositoryImpl repo;
  late FakeAuthRemoteDataSource fakeRemote;

  setUp(() {
    fakeRemote = FakeAuthRemoteDataSource();
    repo = AuthRepositoryImpl(
      remote: fakeRemote,
      local: AuthLocalDataSourceImpl(FakeStorageService()),
    );
  });

  group('AuthRepository – login', () {
    test('returns UserEntity on valid credentials', () async {
      final result = await repo.login(
        email: 'admin@test.com',
        password: 'admin123',
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) {
          expect(user.email, 'admin@test.com');
          expect(user.firstName, 'Admin');
        },
      );
    });

    test('returns AuthFailure on wrong password', () async {
      fakeRemote.shouldThrowUnauthorized = true;

      final result = await repo.login(
        email: 'admin@test.com',
        password: 'wrongpassword',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Expected Left'),
      );
    });

    test('returns ServerFailure on server error', () async {
      fakeRemote.shouldThrowServer = true;

      final result = await repo.login(
        email: 'admin@test.com',
        password: 'admin123',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  group('AuthRepository – logout', () {
    test('clears session on logout', () async {
      await repo.login(email: 'admin@test.com', password: 'admin123');
      final result = await repo.logout();
      expect(result.isRight(), isTrue);
    });
  });

  // getCurrentUser and refreshSession rely on Supabase.instance.client.auth.currentUser
  // which is null in unit tests (no real Supabase session). These verify that
  // the repository correctly handles the no-session case.
  group('AuthRepository – session (no Supabase session in tests)', () {
    test('getCurrentUser returns null when Supabase has no active session',
        () async {
      final result = await repo.getCurrentUser();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user, isNull),
      );
    });

    test('refreshSession returns NO_SESSION when Supabase has no active session',
        () async {
      final result = await repo.refreshSession();
      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'NO_SESSION'),
        (_) => fail('Expected Left'),
      );
    });
  });
}

// ── Fake remote datasource ────────────────────────────────────────────────────

class FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  bool shouldThrowUnauthorized = false;
  bool shouldThrowServer = false;

  static const _fakeUser = UserModel(
    id: 'test-user-001',
    email: 'admin@test.com',
    firstName: 'Admin',
    lastName: 'User',
    role: 'admin',
    createdAt: '2024-01-01T00:00:00.000Z',
  );

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    if (shouldThrowUnauthorized) {
      throw const UnauthorizedException(
        'Invalid credentials.',
        code: 'INVALID_CREDENTIALS',
      );
    }
    if (shouldThrowServer) {
      throw const ServerException('Server error.', code: 'SERVER_ERROR');
    }
    return _fakeUser;
  }

  @override
  Future<UserModel> fetchUserProfile(String userId) async => _fakeUser;

  @override
  Future<void> logout() async {}
}

// ── Minimal in-memory StorageService for tests ───────────────────────────────

class FakeStorageService implements StorageService {
  final _store = <String, String>{};

  @override
  Future<void> write({required String key, required String? value}) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({required String key}) async => _store[key];

  @override
  Future<void> delete({required String key}) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}
