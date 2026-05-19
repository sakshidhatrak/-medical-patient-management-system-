import 'package:flutter_test/flutter_test.dart';
import 'package:medical_patient_management/core/error/failures.dart';
import 'package:medical_patient_management/features/auth/data/datasources/auth_local_datasource.dart';
import 'package:medical_patient_management/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:medical_patient_management/features/auth/domain/entities/user_entity.dart';
import 'package:medical_patient_management/core/storage/storage_service.dart';

void main() {
  late AuthRepositoryImpl repo;

  setUp(() {
    repo = AuthRepositoryImpl(
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
          expect(user.role, UserRole.admin);
        },
      );
    });

    test('returns AuthFailure on wrong password', () async {
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

    test('returns AuthFailure on wrong email', () async {
      final result = await repo.login(
        email: 'unknown@test.com',
        password: 'admin123',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<AuthFailure>());
          expect(failure.code, 'INVALID_CREDENTIALS');
        },
        (_) => fail('Expected Left'),
      );
    });
  });

  group('AuthRepository – session', () {
    test('getCurrentUser returns null when no session stored', () async {
      final result = await repo.getCurrentUser();

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user, isNull),
      );
    });

    test('getCurrentUser returns user after successful login', () async {
      await repo.login(email: 'admin@test.com', password: 'admin123');

      final result = await repo.getCurrentUser();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user?.email, 'admin@test.com'),
      );
    });

    test('logout clears stored session', () async {
      await repo.login(email: 'admin@test.com', password: 'admin123');
      await repo.logout();

      final result = await repo.getCurrentUser();
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user, isNull),
      );
    });

    test('refreshSession returns user if session exists', () async {
      await repo.login(email: 'admin@test.com', password: 'admin123');

      final result = await repo.refreshSession();
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (user) => expect(user.email, 'admin@test.com'),
      );
    });

    test('refreshSession returns AuthFailure when no session', () async {
      final result = await repo.refreshSession();

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.code, 'NO_SESSION'),
        (_) => fail('Expected Left'),
      );
    });
  });
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

