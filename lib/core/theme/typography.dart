import 'package:flutter/material.dart';

/// IBM Plex Sans Arabic is bundled (assets/fonts) and covers Arabic + Latin,
/// so one family serves both languages and works offline.
abstract final class AppTypography {
  static const fontFamily = 'IBMPlexSansArabic';

  static TextTheme textTheme(TextTheme base) => base
      .apply(fontFamily: fontFamily)
      .copyWith(
        headlineSmall: base.headlineSmall?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w700),
        titleLarge: base.titleLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        titleMedium: base.titleMedium?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
        labelLarge: base.labelLarge?.copyWith(fontFamily: fontFamily, fontWeight: FontWeight.w600),
      );
}
