import 'package:flutter/material.dart';

/// Per-device display preferences (theme, language, digits, auto-lock).
@immutable
class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.latinDigits = true,
    this.autoLockMinutes = 5,
  });

  final ThemeMode themeMode;

  /// Null = follow profile → store → brand default (TECHNICAL_STRUCTURE §9).
  final Locale? locale;

  /// Show 0-9 instead of ٠-٩ in Arabic.
  final bool latinDigits;
  final int autoLockMinutes;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool clearLocale = false,
    bool? latinDigits,
    int? autoLockMinutes,
  }) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        locale: clearLocale ? null : (locale ?? this.locale),
        latinDigits: latinDigits ?? this.latinDigits,
        autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      );

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.latinDigits == latinDigits &&
      other.autoLockMinutes == autoLockMinutes;

  @override
  int get hashCode => Object.hash(themeMode, locale, latinDigits, autoLockMinutes);
}
