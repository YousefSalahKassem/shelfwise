// OWNER: A6.
import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

/// One row of `app_events`, without anything that identifies a person.
class UsageEventRow {
  const UsageEventRow({
    required this.atMs,
    required this.name,
    this.profileId,
    this.role,
    this.props,
  });

  final int atMs;
  final String name;
  final String? profileId;
  final String? role;
  final String? props;
}

/// The activation numbers a pilot check-in needs (PLAN §7).
class UsageSummary {
  const UsageSummary({
    this.storeCreatedAtMs,
    this.products = 0,
    this.productsWithReorderPoint = 0,
    this.productsWithBarcode = 0,
    this.categories = 0,
    this.profiles = 0,
    this.staffProfiles = 0,
    this.stockMovements = 0,
    this.lastMovementAtMs,
    this.priceChanges = 0,
    this.bulkPriceBatches = 0,
    this.alertsFired = 0,
    this.alertsOut = 0,
    this.alertsOpen = 0,
    this.alertsAcknowledged = 0,
    this.events = 0,
    this.activeDays = 0,
    this.sessionDays = 0,
    this.activeStaffProfiles = 0,
    this.firstEventAtMs,
    this.lastEventAtMs,
    this.importsCompleted = 0,
    this.backupsCreated = 0,
  });

  final int? storeCreatedAtMs;
  final int products;
  final int productsWithReorderPoint;
  final int productsWithBarcode;
  final int categories;
  final int profiles;
  final int staffProfiles;
  final int stockMovements;
  final int? lastMovementAtMs;
  final int priceChanges;
  final int bulkPriceBatches;
  final int alertsFired;
  final int alertsOut;
  final int alertsOpen;
  final int alertsAcknowledged;
  final int events;

  /// Days on which anything at all was logged.
  final int activeDays;

  /// Days with a `session_started` event — the weekly-active-store measure.
  final int sessionDays;
  final int activeStaffProfiles;
  final int? firstEventAtMs;
  final int? lastEventAtMs;
  final int importsCompleted;
  final int backupsCreated;

  /// Business-plan activation test: ≥50 products, ≥10 reorder points,
  /// ≥1 stock movement (PLAN §7).
  bool get isActivated =>
      products >= 50 && productsWithReorderPoint >= 10 && stockMovements >= 1;

  Map<String, Object?> asRows() => {
    'store_created_at': _iso(storeCreatedAtMs),
    'products': products,
    'products_with_reorder_point': productsWithReorderPoint,
    'products_with_barcode': productsWithBarcode,
    'categories': categories,
    'profiles_active': profiles,
    'staff_profiles': staffProfiles,
    'staff_profiles_with_activity': activeStaffProfiles,
    'stock_movements': stockMovements,
    'last_movement_at': _iso(lastMovementAtMs),
    'price_changes': priceChanges,
    'bulk_price_updates': bulkPriceBatches,
    'alerts_fired': alertsFired,
    'alerts_out_of_stock': alertsOut,
    'alerts_open': alertsOpen,
    'alerts_acknowledged': alertsAcknowledged,
    'imports_completed': importsCompleted,
    'backups_created': backupsCreated,
    'events_logged': events,
    'days_with_activity': activeDays,
    'days_with_a_session': sessionDays,
    'first_event_at': _iso(firstEventAtMs),
    'last_event_at': _iso(lastEventAtMs),
    'activated_7day_definition': isActivated ? 'yes' : 'no',
  };
}

/// Builds the pilot export: a header, the activation summary, then every event.
///
/// One CSV file so a check-in only has to collect one attachment. It starts
/// with a UTF-8 BOM because Excel otherwise shows Arabic store names as
/// mojibake.
Uint8List buildUsageCsv({
  required String brandId,
  required String storeId,
  required String storeName,
  required DateTime generatedAt,
  required UsageSummary summary,
  required List<UsageEventRow> events,
}) {
  final rows = <List<Object?>>[
    ['ShelfWise usage export'],
    ['brand', brandId],
    ['store_id', storeId],
    ['store_name', storeName],
    ['generated_at', generatedAt.toUtc().toIso8601String()],
    [],
    ['summary'],
    ['metric', 'value'],
    ...summary.asRows().entries.map((e) => [e.key, e.value ?? '']),
    [],
    ['events'],
    ['timestamp_utc', 'event', 'profile_id', 'role', 'props'],
    ...events.map(
      (e) => [
        _iso(e.atMs) ?? '',
        e.name,
        e.profileId ?? '',
        e.role ?? '',
        e.props ?? '',
      ],
    ),
  ];
  const csv = ListToCsvConverter(eol: '\r\n');
  return Uint8List.fromList(utf8.encode('\uFEFF${csv.convert(rows)}'));
}

String? _iso(int? epochMs) => epochMs == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch(
        epochMs,
        isUtc: true,
      ).toIso8601String();
