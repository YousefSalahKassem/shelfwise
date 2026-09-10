// OWNER: A6. The only place with backup/restore SQL.
import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../models/backup_file.dart';
import '../models/backup_tables.dart';
import '../models/usage_report.dart';

/// Reads every table for a backup and replaces every table on restore.
///
/// This is the only data source in the app that writes outside its own
/// feature's tables (AGENT_PHASES §5.2) — and it does so only inside
/// [replaceAll], in one transaction.
class BackupLocalDataSource {
  const BackupLocalDataSource(this.database);

  final AppDatabase database;

  Future<int> schemaVersion() => database.db.getVersion();

  /// Every row of every table, including soft-deleted ones: a backup restores
  /// the device exactly as it was, deletions included (they matter for sync).
  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in BackupTables.inInsertOrder) {
      final rows = await database.db.query(table);
      // sqflite hands back read-only maps; the encoder needs plain ones.
      tables[table] = [for (final row in rows) Map<String, Object?>.of(row)];
    }
    return tables;
  }

  /// Column names this build's schema actually has, per table.
  Future<Map<String, Set<String>>> liveColumns() async {
    final columns = <String, Set<String>>{};
    for (final table in BackupTables.inInsertOrder) {
      final info = await database.db.rawQuery('PRAGMA table_info($table)');
      columns[table] = {for (final row in info) row['name']! as String};
    }
    return columns;
  }

  /// Deletes everything and inserts [tables] in one transaction: either the
  /// device ends up holding the backup, or it is left exactly as it was.
  Future<void> replaceAll(
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    await database.transaction((txn) async {
      for (final table in BackupTables.inInsertOrder.reversed) {
        await txn.delete(table);
      }
      for (final table in BackupTables.inInsertOrder) {
        final rows = tables[table] ?? const <Map<String, Object?>>[];
        if (rows.isEmpty) continue;
        final batch = txn.batch();
        for (final row in orderedForInsert(table, rows)) {
          batch.insert(table, row);
        }
        await batch.commit(noResult: true);
      }
    });
  }

  /// Every logged event, oldest first, with the role of the profile that
  /// caused it (names are left out — the export leaves the store).
  Future<List<UsageEventRow>> events() async {
    final rows = await database.db.rawQuery(
      'SELECT e.${C.createdAt} AS at, e.name AS name, e.${C.profileId} AS profile_id, '
      'p.role AS role, e.props AS props '
      'FROM ${T.appEvents} e '
      'LEFT JOIN ${T.profiles} p ON p.${C.id} = e.${C.profileId} '
      'WHERE e.${C.deletedAt} IS NULL '
      'ORDER BY e.${C.createdAt}',
    );
    return [
      for (final row in rows)
        UsageEventRow(
          atMs: (row['at'] as int?) ?? 0,
          name: (row['name'] as String?) ?? '',
          profileId: row['profile_id'] as String?,
          role: row['role'] as String?,
          props: row['props'] as String?,
        ),
    ];
  }

  /// The activation numbers the pilot check-in asks for (PLAN §7).
  Future<UsageSummary> summary() async {
    Future<int> count(String sql, [List<Object?> args = const []]) async {
      final rows = await database.db.rawQuery(sql, args);
      return rows.isEmpty ? 0 : (rows.first.values.first as int? ?? 0);
    }

    Future<int?> value(String sql, [List<Object?> args = const []]) async {
      final rows = await database.db.rawQuery(sql, args);
      return rows.isEmpty ? null : rows.first.values.first as int?;
    }

    const live = '${C.deletedAt} IS NULL';
    const eventDay = "date(${C.createdAt} / 1000, 'unixepoch')";

    return UsageSummary(
      storeCreatedAtMs: await value(
        'SELECT MIN(${C.createdAt}) FROM ${T.stores} WHERE $live',
      ),
      products: await count(
        'SELECT COUNT(*) FROM ${T.products} WHERE $live AND is_archived = 0',
      ),
      productsWithReorderPoint: await count(
        'SELECT COUNT(*) FROM ${T.products} WHERE $live AND is_archived = 0 AND reorder_point_milli > 0',
      ),
      productsWithBarcode: await count(
        'SELECT COUNT(*) FROM ${T.products} WHERE $live AND is_archived = 0 AND barcode IS NOT NULL',
      ),
      categories: await count(
        'SELECT COUNT(*) FROM ${T.categories} WHERE $live',
      ),
      profiles: await count(
        'SELECT COUNT(*) FROM ${T.profiles} WHERE $live AND is_active = 1',
      ),
      staffProfiles: await count(
        "SELECT COUNT(*) FROM ${T.profiles} WHERE $live AND is_active = 1 AND role = 'staff'",
      ),
      stockMovements: await count(
        'SELECT COUNT(*) FROM ${T.stockMovements} WHERE $live',
      ),
      lastMovementAtMs: await value(
        'SELECT MAX(${C.createdAt}) FROM ${T.stockMovements} WHERE $live',
      ),
      priceChanges: await count(
        'SELECT COUNT(*) FROM ${T.priceChanges} WHERE $live',
      ),
      bulkPriceBatches: await count(
        'SELECT COUNT(DISTINCT batch_id) FROM ${T.priceChanges} WHERE $live AND batch_id IS NOT NULL',
      ),
      alertsFired: await count(
        'SELECT COUNT(*) FROM ${T.stockAlerts} WHERE $live',
      ),
      alertsOut: await count(
        "SELECT COUNT(*) FROM ${T.stockAlerts} WHERE $live AND level = 'out'",
      ),
      alertsOpen: await count(
        'SELECT COUNT(*) FROM ${T.stockAlerts} WHERE $live AND resolved_at IS NULL',
      ),
      alertsAcknowledged: await count(
        'SELECT COUNT(*) FROM ${T.stockAlerts} WHERE $live AND acknowledged_at IS NOT NULL',
      ),
      events: await count('SELECT COUNT(*) FROM ${T.appEvents} WHERE $live'),
      activeDays: await count(
        'SELECT COUNT(DISTINCT $eventDay) FROM ${T.appEvents} WHERE $live',
      ),
      sessionDays: await count(
        "SELECT COUNT(DISTINCT $eventDay) FROM ${T.appEvents} WHERE $live AND name = 'session_started'",
      ),
      activeStaffProfiles: await count(
        "SELECT COUNT(DISTINCT e.${C.profileId}) FROM ${T.appEvents} e "
        "JOIN ${T.profiles} p ON p.${C.id} = e.${C.profileId} "
        "WHERE e.$live AND p.role = 'staff'",
      ),
      firstEventAtMs: await value(
        'SELECT MIN(${C.createdAt}) FROM ${T.appEvents} WHERE $live',
      ),
      lastEventAtMs: await value(
        'SELECT MAX(${C.createdAt}) FROM ${T.appEvents} WHERE $live',
      ),
      importsCompleted: await count(
        "SELECT COUNT(*) FROM ${T.appEvents} WHERE $live AND name = 'import_completed'",
      ),
      backupsCreated: await count(
        "SELECT COUNT(*) FROM ${T.appEvents} WHERE $live AND name = 'backup_created'",
      ),
    );
  }
}
