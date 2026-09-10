// OWNER: A1 (replaces this stub with persistence in the `settings` table).
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../brand/brand_providers.dart';
import 'app_preferences.dart';

part 'preferences_impl.g.dart';

/// In-memory in W0. Keep the provider name, state type and method names.
@Riverpod(keepAlive: true)
class PreferencesController extends _$PreferencesController {
  @override
  AppPreferences build() {
    final brand = ref.watch(brandConfigProvider);
    return AppPreferences(latinDigits: brand.latinDigitsByDefault);
  }

  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);

  /// Null follows profile/store/brand default.
  void setLocale(Locale? locale) =>
      state = locale == null ? state.copyWith(clearLocale: true) : state.copyWith(locale: locale);

  void setLatinDigits(bool value) => state = state.copyWith(latinDigits: value);

  void setAutoLockMinutes(int minutes) => state = state.copyWith(autoLockMinutes: minutes);
}
