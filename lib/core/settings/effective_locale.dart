import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../brand/brand_providers.dart';
import '../session/session_impl.dart';
import '../utils/formatters.dart';
import 'preferences_impl.dart';

part 'effective_locale.g.dart';

/// Locale priority (TECHNICAL_STRUCTURE §9): device preference override →
/// profile → store → brand default. Always one of the brand's supported locales.
@Riverpod(keepAlive: true)
Locale effectiveLocale(Ref ref) {
  final brand = ref.watch(brandConfigProvider);
  final prefs = ref.watch(preferencesControllerProvider);
  final session = ref.watch(sessionControllerProvider);
  final candidates = [
    prefs.locale?.languageCode,
    session.profile?.locale,
    session.store?.locale,
    brand.defaultLocale.languageCode,
  ];
  for (final code in candidates) {
    if (code == null) continue;
    for (final l in brand.supportedLocales) {
      if (l.languageCode == code) return l;
    }
  }
  return brand.defaultLocale;
}

@Riverpod(keepAlive: true)
AppFormatters appFormatters(Ref ref) => AppFormatters(
      languageCode: ref.watch(effectiveLocaleProvider).languageCode,
      latinDigits: ref.watch(preferencesControllerProvider).latinDigits,
    );
