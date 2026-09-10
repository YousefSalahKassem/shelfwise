import 'package:flutter/material.dart';

import '../brand/brand_config.dart';
import 'spacing.dart';
import 'stock_colors.dart';
import 'typography.dart';

/// Theme = brand palette × brightness (TECHNICAL_STRUCTURE §8).
ThemeData buildTheme(BrandConfig brand, Brightness brightness) {
  var scheme = ColorScheme.fromSeed(seedColor: brand.primary, brightness: brightness);
  if (brightness == Brightness.light) {
    // Use the brand's exact colours in light mode when they're readable.
    final primary = ensureContrast(brand.primary, scheme.surface);
    final secondary = ensureContrast(brand.secondary, scheme.surface);
    scheme = scheme.copyWith(
      primary: primary,
      onPrimary: onColorFor(primary),
      secondary: secondary,
      onSecondary: onColorFor(secondary),
    );
  }
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    textTheme: AppTypography.textTheme(base.textTheme),
    extensions: [brightness == Brightness.dark ? StockColors.dark : StockColors.light],
    visualDensity: VisualDensity.standard,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadii.md))),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(AppSpacing.minTarget, AppSpacing.minTarget)),
    ),
  );
}

/// WCAG contrast ratio between two colours (1–21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color onColorFor(Color background) =>
    contrastRatio(background, Colors.white) >= contrastRatio(background, Colors.black)
        ? Colors.white
        : Colors.black;

/// Darkens [color] until it reaches [minRatio] against [background].
Color ensureContrast(Color color, Color background, {double minRatio = 4.5}) {
  var c = color;
  var hsl = HSLColor.fromColor(c);
  var guard = 0;
  while (contrastRatio(c, background) < minRatio && guard++ < 40) {
    hsl = hsl.withLightness((hsl.lightness - 0.02).clamp(0.0, 1.0));
    c = hsl.toColor();
  }
  return c;
}
