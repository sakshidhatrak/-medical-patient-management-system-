import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/sync/sync_engine.dart';
import 'features/auth/domain/entities/user_entity.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

// Pass --dart-define=BYPASS_LOGIN=true to skip authentication for testing.
const bool _bypassLogin =
    bool.fromEnvironment('BYPASS_LOGIN', defaultValue: false);

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthAuthenticated(
        UserEntity(
          id: 'test-user-001',
          email: 'test@medimanage.com',
          firstName: 'Test',
          lastName: 'Doctor',
          role: UserRole.doctor,
          createdAt: DateTime(2024, 1, 1),
        ),
      );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  // Orientation lock is a no-op on web and desktop; skip it there.
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // On web, SharedPreferences backs the storage layer.
  // Pre-initialise it here so the sync Riverpod provider can receive it.
  final overrides = <Override>[];
  if (kIsWeb) {
    final prefs = await SharedPreferences.getInstance();
    overrides.add(sharedPreferencesProvider.overrideWithValue(prefs));
  }
  if (_bypassLogin) {
    overrides.add(authProvider.overrideWith(_MockAuthNotifier.new));
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      observers: [_AppProviderObserver()],
      child: const _SyncInit(child: App()),
    ),
  );
}

/// Boots the sync coordinator so it watches connectivity changes app-wide.
class _SyncInit extends ConsumerWidget {
  final Widget child;
  const _SyncInit({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(syncCoordinatorProvider);
    return child;
  }
}

class _AppProviderObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (EnvConfig.isDevelopment) {
      debugPrint('[Riverpod] ${provider.name ?? provider.runtimeType} updated');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    debugPrint('[Riverpod] ${provider.name ?? provider.runtimeType} FAILED: $error');
  }
}
