import 'package:meta/meta.dart';

import 'feature_flag.dart';
import 'tier.dart';

/// What a brand can use, derived from its [Tier] plus optional per-brand
/// overrides in brand.json (`featureOverrides`, e.g. for a pilot).
/// Single source of truth for gating — UI hides, use cases enforce.
@immutable
class FeatureFlags {
  const FeatureFlags({required this.tier, this.overrides = const {}});

  final Tier tier;
  final Map<FeatureFlag, bool> overrides;

  static const Set<FeatureFlag> _shelf = {
    FeatureFlag.stockCount,
    FeatureFlag.basicReports,
    FeatureFlag.billing,
  };

  static const Set<FeatureFlag> _aisle = {
    ..._shelf,
    FeatureFlag.activityLog,
    FeatureFlag.advancedReports,
    FeatureFlag.multiBranch,
    FeatureFlag.suppliers,
    FeatureFlag.customRoles,
    FeatureFlag.expiryDates,
    FeatureFlag.customDomain,
    FeatureFlag.nativeBrandApps,
    FeatureFlag.priceHistory,
    FeatureFlag.labelPrinting,
    FeatureFlag.whatsappAlerts,
  };

  static final Set<FeatureFlag> _chain = FeatureFlag.values.toSet();

  static Set<FeatureFlag> defaultsFor(Tier tier) => switch (tier) {
        Tier.shelf => _shelf,
        Tier.aisle => _aisle,
        Tier.chain => _chain,
      };

  bool isEnabled(FeatureFlag flag) => overrides[flag] ?? defaultsFor(tier).contains(flag);

  /// Max active staff profiles per store; null = unlimited. (Shelf tier: 3.)
  int? get maxStaffProfiles => tier == Tier.shelf ? 3 : null;
}
