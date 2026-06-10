import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/storage/storage_service.dart';
import '../../../../core/usecases/use_case.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';

// ── Storage providers ────────────────────────────────────────────────────────

/// Overridden in main.dart on web with a pre-initialised SharedPreferences.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden before runApp on web.',
  ),
);

final storageServiceProvider = Provider<StorageService>((ref) {
  if (kIsWeb) {
    return WebStorageService(ref.watch(sharedPreferencesProvider));
  }
  return const SecureStorageService(
    FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
});

// ── Supabase provider ────────────────────────────────────────────────────────

final supabaseClientProvider = Provider<sb.SupabaseClient>(
  (_) => sb.Supabase.instance.client,
);

// ── Repository / use-case providers ─────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(ref.watch(supabaseClientProvider));
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
    final subscription =
        sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case sb.AuthChangeEvent.signedIn:
        case sb.AuthChangeEvent.tokenRefreshed:
          _loadUserFromSession();
        case sb.AuthChangeEvent.signedOut:
          state = const AuthUnauthenticated();
        default:
          break;
      }
    });
    ref.onDispose(subscription.cancel);

    _checkSession();
    return const AuthInitial();
  }

  Future<void> _loadUserFromSession() async {
    final result = await ref.read(authRepositoryProvider).getCurrentUser();
    state = result.fold(
      (_) => const AuthUnauthenticated(),
      (user) =>
          user != null ? AuthAuthenticated(user) : const AuthUnauthenticated(),
    );
  }

  Future<void> _checkSession() async {
    final result = await ref.read(authRepositoryProvider).getCurrentUser();
    state = result.fold(
      (_) => const AuthUnauthenticated(),
      (user) =>
          user != null ? AuthAuthenticated(user) : const AuthUnauthenticated(),
    );
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
