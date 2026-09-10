import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/brand/brand_config.dart';
import 'package:shelfwise/core/brand/feature_flag.dart';
import 'package:shelfwise/core/brand/feature_flags.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/theme/app_theme.dart';

Map<String, Object?> _valid() => {
      'id': 'acme',
      'appName': 'Acme Stock',
      'tier': 'shelf',
      'colors': {'primary': '#0D6A56', 'secondary': '#A86F00'},
      'logo': 'assets/brands/acme/logo.png',
      'defaultLocale': 'ar',
      'supportedLocales': ['ar', 'en'],
      'defaultCurrency': 'EGP',
    };

void main() {
  test('parses a valid brand', () {
    final b = BrandConfig.fromJson(_valid());
    expect(b.id, 'acme');
    expect(b.tier, Tier.shelf);
    expect(b.logoDarkAsset, b.logoAsset, reason: 'falls back to logo');
    expect(b.defaultLocale.languageCode, 'ar');
  });

  test('reports every problem at once', () {
    final json = _valid()
      ..['id'] = 'Bad Id'
      ..['tier'] = 'gold'
      ..['colors'] = {'primary': 'green', 'secondary': '#123456'}
      ..['defaultCurrency'] = 'USD'
      ..['supportedLocales'] = ['en', 'fr'];
    try {
      BrandConfig.fromJson(json);
      fail('should throw');
    } on BrandConfigException catch (e) {
      expect(e.issues.length, greaterThanOrEqualTo(5));
    }
  });

  test('every bundled brand.json is valid and matches its folder', () {
    final dir = Directory('assets/brands');
    for (final brandDir in dir.listSync().whereType<Directory>()) {
      final id = brandDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final json = jsonDecode(File('${brandDir.path}/brand.json').readAsStringSync()) as Map;
      final b = BrandConfig.fromJson(json.cast<String, Object?>());
      expect(b.id, id);
      for (final asset in [b.logoAsset, b.logoDarkAsset, b.iconAsset]) {
        expect(File(asset).existsSync(), isTrue, reason: '$asset missing');
      }
    }
  });

  group('FeatureFlags', () {
    test('tier defaults', () {
      const shelf = FeatureFlags(tier: Tier.shelf);
      const aisle = FeatureFlags(tier: Tier.aisle);
      const chain = FeatureFlags(tier: Tier.chain);
      expect(shelf.isEnabled(FeatureFlag.stockCount), isTrue);
      expect(shelf.isEnabled(FeatureFlag.multiBranch), isFalse);
      expect(aisle.isEnabled(FeatureFlag.multiBranch), isTrue);
      expect(aisle.isEnabled(FeatureFlag.hqMasterCatalogue), isFalse);
      expect(chain.isEnabled(FeatureFlag.hqMasterCatalogue), isTrue);
      expect(shelf.maxStaffProfiles, 3);
      expect(aisle.maxStaffProfiles, isNull);
    });
    test('overrides win', () {
      const f = FeatureFlags(tier: Tier.shelf, overrides: {FeatureFlag.multiBranch: true});
      expect(f.isEnabled(FeatureFlag.multiBranch), isTrue);
    });
  });

  test('brand colours reach 4.5:1 contrast in light theme', () {
    final b = BrandConfig.fromJson(_valid()..['colors'] = {'primary': '#9BE15D', 'secondary': '#FFD166'});
    final theme = buildTheme(b, Brightness.light);
    expect(contrastRatio(theme.colorScheme.primary, theme.colorScheme.surface), greaterThanOrEqualTo(4.5));
  });
}
