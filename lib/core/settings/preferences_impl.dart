// OWNER: A1. Persists the display preferences in the `settings` table.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/settings/public.dart';
import '../brand/brand_providers.dart';
import 'app_preferences.dart';

part 'preferences_impl.g.dart';

/// Theme mode, language, digits and auto-lock, stored per device.
///
/// [build] must stay synchronous (the app reads it on the first frame), so it
/// returns the brand defaults and the stored values arrive a moment later.
@Riverpod(keepAlive: true)
class PreferencesController extends _$PreferencesController {
  SettingsRepository? get _repository => ref.read(settingsRepositoryProvider);

  /// Completes once the stored preferences have been applied. Tests await it;
  /// the app doesn't need to.
  late Future<void> restored;

  @override
  AppPreferences build() {
    final brand = ref.watch(brandConfigProvider);
    restored = _restore(AppPreferences(latinDigits: brand.latinDigitsByDefault));
    return AppPreferences(latinDigits: brand.latinDigitsByDefault);
  }

  Future<void> _restore(AppPreferences defaults) async {
    final repository = _repository;
    if (repository == null) return;
    final stored = (await repository.readAll()).valueOrNull;
    if (stored == null || !ref.mounted) return;

    final locale = stored[SettingKeys.locale];
    state = AppPreferences(
      themeMode: _themeMode(stored[SettingKeys.themeMode]) ?? defaults.themeMode,
      locale: locale == null || locale.isEmpty ? null : Locale(locale),
      latinDigits: switch (stored[SettingKeys.latinDigits]) {
        'true' => true,
        'false' => false,
        _ => defaults.latinDigits,
      },
      autoLockMinutes:
          int.tryParse(stored[SettingKeys.autoLockMinutes] ?? '') ?? defaults.autoLockMinutes,
    );
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _persist(SettingKeys.themeMode, mode.name);
  }

  /// Null follows profile/store/brand default.
  void setLocale(Locale? locale) {
    state = locale == null ? state.copyWith(clearLocale: true) : state.copyWith(locale: locale);
    if (locale == null) {
      unawaited(_repository?.remove(SettingKeys.locale));
    } else {
      _persist(SettingKeys.locale, locale.languageCode);
    }
  }

  void setLatinDigits(bool value) {
    state = state.copyWith(latinDigits: value);
    _persist(SettingKeys.latinDigits, '$value');
  }

  /// 0 means "never lock automatically".
  void setAutoLockMinutes(int minutes) {
    final clamped = minutes < 0 ? 0 : minutes;
    state = state.copyWith(autoLockMinutes: clamped);
    _persist(SettingKeys.autoLockMinutes, '$clamped');
  }

  void _persist(String key, String value) => unawaited(_repository?.write(key, value));

  static ThemeMode? _themeMode(String? name) {
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }
}
