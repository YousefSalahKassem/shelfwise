// OWNER: A6.
import '../../../../core/database/schema/tables.dart';

/// Every table a backup carries, ordered so that a row's foreign keys already
/// exist when it is inserted. Restore inserts in this order and deletes in the
/// reverse one, because `PRAGMA foreign_keys` stays on inside the transaction.
abstract final class BackupTables {
  static const inInsertOrder = <String>[
    T.stores,
    T.branches,
    T.profiles,
    T.categories,
    T.products,
    T.productImages,
    T.stockLevels,
    T.stockMovements,
    T.priceChanges,
    T.stockAlerts,
    T.appEvents,
    T.settings,
  ];

  static const known = <String>{...inInsertOrder};
}
