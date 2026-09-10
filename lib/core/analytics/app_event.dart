/// Pilot metric events (TECHNICAL_STRUCTURE §11, business plan §9).
/// Adding an event is a contract change — request it from the lead.
enum AppEvent {
  storeCreated('store_created'),
  sessionStarted('session_started'),
  profileSwitched('profile_switched'),
  productCreated('product_created'),
  reorderPointSet('reorder_point_set'),
  stockMovementRecorded('stock_movement_recorded'),
  bulkPriceUpdated('bulk_price_updated'),
  lowStockAlertFired('low_stock_alert_fired'),
  alertOpened('alert_opened'),
  importCompleted('import_completed'),
  backupCreated('backup_created');

  const AppEvent(this.wireName);

  /// Stored in `app_events.name` and sent to any future cloud analytics.
  final String wireName;
}
