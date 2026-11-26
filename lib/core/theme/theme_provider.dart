import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
}

@Riverpod(keepAlive: true)
class ThemeModeNotifier extends _$ThemeModeNotifier {
  static const String _storageKey = 'theme_mode';

  // region: BUILD
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _fromStorage(prefs.getString(_storageKey));
  }
  // endregion

  // region: ACTIONS
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) {
      return;
    }
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, mode.name);
  }

  ThemeMode _fromStorage(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
  // endregion
}
