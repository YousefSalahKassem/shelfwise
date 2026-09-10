import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'brand_config.dart';
import 'feature_flags.dart';

part 'brand_providers.g.dart';

/// Loaded in `bootstrap.dart` and injected with `overrideWithValue`.
@Riverpod(keepAlive: true)
BrandConfig brandConfig(Ref ref) =>
    throw UnimplementedError('brandConfigProvider must be overridden in bootstrap');

@Riverpod(keepAlive: true)
FeatureFlags featureFlags(Ref ref) {
  final brand = ref.watch(brandConfigProvider);
  return FeatureFlags(tier: brand.tier, overrides: brand.featureOverrides);
}
