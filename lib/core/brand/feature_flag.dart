/// Every tier-gated feature (AGENT_PHASES §4). Core MVP features (catalogue,
/// prices, stock, low-stock alerts, CSV, scanning, AR/EN) are not flags —
/// every tier has them.
enum FeatureFlag {
  // Should
  stockCount,
  activityLog,
  basicReports,
  advancedReports,
  multiBranch,
  suppliers,
  customRoles,
  expiryDates,
  hqMasterCatalogue,
  customDomain,
  nativeBrandApps,
  // Could
  priceHistory,
  labelPrinting,
  whatsappAlerts,
  api,
  posSync,
  sso,
  smartReorder,
  billing,
  multiCurrency;

  static FeatureFlag? tryParse(String name) {
    for (final f in FeatureFlag.values) {
      if (f.name == name) return f;
    }
    return null;
  }
}
