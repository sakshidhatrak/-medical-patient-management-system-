import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/storage_provider.dart';

const _kThemeKey = 'app_theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    // Read persisted preference; default to light if not set.
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_kThemeKey);
    return saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void toggle() {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    ref.read(sharedPreferencesProvider).setString(
          _kThemeKey,
          next == ThemeMode.dark ? 'dark' : 'light',
        );
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
