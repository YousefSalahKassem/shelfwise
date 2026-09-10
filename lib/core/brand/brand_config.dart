import 'dart:ui' show Color, Locale;

import 'package:meta/meta.dart';

import 'feature_flag.dart';
import 'tier.dart';

class BrandConfigException implements Exception {
  BrandConfigException(this.issues);
  final List<String> issues;
  @override
  String toString() => 'Invalid brand.json:\n- ${issues.join('\n- ')}';
}

@immutable
class BrandContact {
  const BrandContact({this.phone, this.whatsapp, this.email});
  final String? phone;
  final String? whatsapp;
  final String? email;
}

/// Everything that differs between white-label clients (AD-4). Loaded from
/// `assets/brands/<id>/brand.json` — see TECHNICAL_STRUCTURE §7.
@immutable
class BrandConfig {
  const BrandConfig({
    required this.id,
    required this.appName,
    required this.tier,
    required this.primary,
    required this.secondary,
    required this.logoAsset,
    required this.logoDarkAsset,
    required this.iconAsset,
    required this.defaultLocale,
    required this.supportedLocales,
    required this.defaultCurrency,
    this.latinDigitsByDefault = true,
    this.featureOverrides = const {},
    this.support = const BrandContact(),
    this.companyName,
    this.privacyUrl,
  });

  final String id;
  final String appName;
  final Tier tier;
  final Color primary;
  final Color secondary;
  final String logoAsset;
  final String logoDarkAsset;
  final String iconAsset;
  final Locale defaultLocale;
  final List<Locale> supportedLocales;
  final String defaultCurrency;
  final bool latinDigitsByDefault;
  final Map<FeatureFlag, bool> featureOverrides;
  final BrandContact support;
  final String? companyName;
  final String? privacyUrl;

  static const supportedCurrencies = {'EGP', 'SAR'};
  static const knownLocales = {'ar', 'en'};

  /// Parses and validates. Throws [BrandConfigException] listing every problem,
  /// so a bad brand fails the build script instead of reaching a user.
  factory BrandConfig.fromJson(Map<String, Object?> json) {
    final issues = <String>[];

    String str(String key, {bool required = true}) {
      final v = json[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (required) issues.add('"$key" must be a non-empty string');
      return '';
    }

    Color color(Map<String, Object?> colors, String key) {
      final v = colors[key];
      if (v is String) {
        final c = tryParseHexColor(v);
        if (c != null) return c;
      }
      issues.add('"colors.$key" must be a hex colour like #0D6A56');
      return const Color(0xFF000000);
    }

    final id = str('id');
    if (id.isNotEmpty && !RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$').hasMatch(id)) {
      issues.add('"id" must be lowercase letters, digits and dashes (2–40 chars)');
    }
    final appName = str('appName');
    final tier = Tier.tryParse(json['tier'] as String?);
    if (tier == null) issues.add('"tier" must be one of shelf, aisle, chain');

    final colors = json['colors'];
    final colorMap = colors is Map ? colors.cast<String, Object?>() : <String, Object?>{};
    if (colors is! Map) issues.add('"colors" must be an object');
    final primary = color(colorMap, 'primary');
    final secondary = color(colorMap, 'secondary');

    final logo = str('logo');
    final logoDark = str('logoDark', required: false);
    final icon = str('icon', required: false);

    final supported = <Locale>[];
    final rawLocales = json['supportedLocales'];
    if (rawLocales is List && rawLocales.isNotEmpty) {
      for (final l in rawLocales) {
        if (l is String && knownLocales.contains(l)) {
          supported.add(Locale(l));
        } else {
          issues.add('Unsupported locale "$l" (known: ${knownLocales.join(', ')})');
        }
      }
    } else {
      issues.add('"supportedLocales" must be a non-empty list');
    }
    final defaultLocale = str('defaultLocale');
    if (defaultLocale.isNotEmpty && !supported.any((l) => l.languageCode == defaultLocale)) {
      issues.add('"defaultLocale" must be one of supportedLocales');
    }

    final currency = str('defaultCurrency');
    if (currency.isNotEmpty && !supportedCurrencies.contains(currency)) {
      issues.add('"defaultCurrency" must be one of ${supportedCurrencies.join(', ')}');
    }

    final overrides = <FeatureFlag, bool>{};
    final rawOverrides = json['featureOverrides'];
    if (rawOverrides is Map) {
      rawOverrides.forEach((k, v) {
        final flag = FeatureFlag.tryParse('$k');
        if (flag == null || v is! bool) {
          issues.add('featureOverrides: unknown flag or non-bool value for "$k"');
        } else {
          overrides[flag] = v;
        }
      });
    }

    final support = json['support'];
    final supportMap = support is Map ? support.cast<String, Object?>() : const <String, Object?>{};
    final legal = json['legal'];
    final legalMap = legal is Map ? legal.cast<String, Object?>() : const <String, Object?>{};

    if (issues.isNotEmpty) throw BrandConfigException(issues);

    return BrandConfig(
      id: id,
      appName: appName,
      tier: tier!,
      primary: primary,
      secondary: secondary,
      logoAsset: logo,
      logoDarkAsset: logoDark.isEmpty ? logo : logoDark,
      iconAsset: icon.isEmpty ? logo : icon,
      defaultLocale: Locale(defaultLocale),
      supportedLocales: supported,
      defaultCurrency: currency,
      latinDigitsByDefault: json['latinDigitsByDefault'] as bool? ?? true,
      featureOverrides: overrides,
      support: BrandContact(
        phone: supportMap['phone'] as String?,
        whatsapp: supportMap['whatsapp'] as String?,
        email: supportMap['email'] as String?,
      ),
      companyName: legalMap['companyName'] as String?,
      privacyUrl: legalMap['privacyUrl'] as String?,
    );
  }
}

/// `#RRGGBB` or `#AARRGGBB` → [Color].
Color? tryParseHexColor(String hex) {
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}
