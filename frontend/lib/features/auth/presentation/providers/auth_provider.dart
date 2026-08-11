import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/storage_provider.dart';
import '../../../../core/usecases/use_case.dart';
import '../../../medicines/data/medicine_service.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

// ── Repository / use-case providers ─────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthSpringDataSourceImpl();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    local: AuthLocalDataSourceImpl(ref.watch(storageServiceProvider)),
  );
});

final _loginUseCaseProvider = Provider<LoginUseCase>(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);

final _logoutUseCaseProvider = Provider<LogoutUseCase>(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);

// ── Auth state ───────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkSession();
    return const AuthInitial();
  }

  Future<void> _checkSession() async {
    final cached = await ref.read(authRepositoryProvider).getCurrentUser();
    final localUser = cached.fold((_) => null, (u) => u);
    state = localUser != null
        ? AuthAuthenticated(localUser)
        : const AuthUnauthenticated();
    if (state is AuthAuthenticated) {
      final svc = ref.read(medicineServiceProvider);
      unawaited(svc.seedMasterIfEmpty());
      unawaited(svc.syncDrugsFromApi());
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    final result = await ref
        .read(_loginUseCaseProvider)
        .call(LoginParams(email: email, password: password));
    state = result.fold(
      (failure) => AuthError(failure.message),
      AuthAuthenticated.new,
    );
    if (state is AuthAuthenticated) {
      final svc = ref.read(medicineServiceProvider);
      // Re-seed the master list first (in case it was cleared), then refresh
      // from the backend. Both are fire-and-forget.
      unawaited(svc.seedMasterIfEmpty());
      unawaited(svc.syncDrugsFromApi());
    }
  }

  Future<void> logout() async {
    state = const AuthLoading();
    final result =
        await ref.read(_logoutUseCaseProvider).call(const NoParams());
    state = result.fold(
      (failure) => AuthError(failure.message),
      (_) => const AuthUnauthenticated(),
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

/// Exposes the current logged-in user, or null if unauthenticated.
final currentUserProvider = Provider<UserEntity?>((ref) {
  final state = ref.watch(authProvider);
  return state is AuthAuthenticated ? state.user : null;
});

/// True only for admin users; all other roles are read-only (view-only).
final canWriteProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.canWrite ?? false;
});
