import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    ProviderScope(
      overrides: overrides,
      observers: [_AppProviderObserver()],
      child: const App(),
    ),
  );
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
