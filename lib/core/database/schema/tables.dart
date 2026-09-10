/// Table names and shared column names. SQL outside this folder and
/// `data/datasources/` must reference these constants, not string literals.
abstract final class T {
  static const stores = 'stores';
  static const branches = 'branches';
  static const profiles = 'profiles';
  static const categories = 'categories';
  static const products = 'products';
  static const productImages = 'product_images';
  static const stockLevels = 'stock_levels';
  static const stockMovements = 'stock_movements';
  static const priceChanges = 'price_changes';
  static const stockAlerts = 'stock_alerts';
  static const appEvents = 'app_events';
  static const settings = 'settings';
}

/// Columns present on every table (sync-ready, AD-2).
abstract final class C {
  static const id = 'id';
  static const createdAt = 'created_at';
  static const updatedAt = 'updated_at';
  static const deletedAt = 'deleted_at';
  static const storeId = 'store_id';
  static const branchId = 'branch_id';
  static const productId = 'product_id';
  static const profileId = 'profile_id';
}
