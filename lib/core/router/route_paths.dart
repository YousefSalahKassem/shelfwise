/// Every route path in the MVP. Frozen contract — agents navigate with these
/// constants (and the `…For()` helpers), never with string literals.
abstract final class RoutePaths {
  // Full-screen (outside the navigation shell)
  static const onboarding = '/onboarding';
  static const lock = '/lock';

  // Shell
  static const dashboard = '/dashboard';
  static const products = '/products';
  static const productNew = '/products/new';
  static const productDetail = '/products/:id';
  static const productEdit = '/products/:id/edit';
  static const categories = '/categories';
  static const stock = '/stock';
  static const stockReceive = '/stock/receive';
  static const stockAdjust = '/stock/adjust';
  static const stockCount = '/stock/count';
  static const alerts = '/alerts';
  static const pricesBulk = '/prices/bulk';
  static const priceEdit = '/prices/:productId';
  static const settings = '/settings';
  static const settingsProfiles = '/settings/profiles';
  static const settingsBackup = '/settings/backup';
  static const settingsImport = '/settings/import';
  static const devPlatform = '/dev/platform';

  static String productDetailFor(String id) => '/products/$id';
  static String productEditFor(String id) => '/products/$id/edit';
  static String priceEditFor(String productId) => '/prices/$productId';

  static const initial = dashboard;
}
