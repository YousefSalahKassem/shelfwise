// OWNER: A6.
import '../../../core/database/schema/tables.dart';
import '../../../core/error/failure.dart';
import '../../../core/l10n/failure_messages.dart';
import '../../../core/l10n/l10n.dart';

/// Turns a [Failure] from this feature into a sentence the store owner can act
/// on. Everything the file checks arrives as `ValidationFailure(field: 'file')`
/// with one of the codes below; anything else falls back to the shared
/// messages (`failureMessage`).
String backupFailureMessage(AppLocalizations l10n, Failure failure, {required String appName}) {
  if (failure is ValidationFailure && failure.field == 'file') {
    return switch (failure.code) {
      'not_backup' => l10n.backup_errorNotBackup,
      'corrupt' => l10n.backup_errorCorrupt,
      'brand_mismatch' => l10n.backup_errorWrongBrand(appName),
      'newer_schema' => l10n.backup_errorNewerSchema,
      'empty' => l10n.backup_errorEmpty,
      _ => failureMessage(l10n, failure),
    };
  }
  return failureMessage(l10n, failure);
}

/// Table name → the words a shop owner uses. Unknown tables (a future
/// migration before this map is updated) show their raw name rather than
/// hiding a row from the restore summary.
String backupTableLabel(AppLocalizations l10n, String table) => switch (table) {
      T.stores => l10n.backup_tableStores,
      T.branches => l10n.backup_tableBranches,
      T.profiles => l10n.backup_tableProfiles,
      T.categories => l10n.backup_tableCategories,
      T.products => l10n.backup_tableProducts,
      T.productImages => l10n.backup_tableProductImages,
      T.stockLevels => l10n.backup_tableStockLevels,
      T.stockMovements => l10n.backup_tableStockMovements,
      T.priceChanges => l10n.backup_tablePriceChanges,
      T.stockAlerts => l10n.backup_tableStockAlerts,
      T.appEvents => l10n.backup_tableAppEvents,
      T.settings => l10n.backup_tableSettings,
      _ => table,
    };
