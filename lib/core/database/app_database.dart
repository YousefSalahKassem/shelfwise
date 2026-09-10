import 'package:sqflite_common/sqlite_api.dart';

import 'migrations/migration.dart';

/// Owns the sqflite [Database] and runs migrations. Feature data sources get
/// it through `appDatabaseProvider`; they never open databases themselves.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static Future<AppDatabase> open({
    required DatabaseFactory factory,
    required String path,
    List<Migration> migrations = allMigrations,
    bool singleInstance = true,
  }) async {
    final target = migrations.last.version;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: target,
        singleInstance: singleInstance,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          for (final m in migrations) {
            await m.up(db);
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          for (final m in migrations.where((m) => m.version > oldVersion && m.version <= newVersion)) {
            await m.up(db);
          }
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<int> get schemaVersion => db.getVersion();

  /// Runs [action] in one exclusive transaction. Keep transactions short.
  Future<R> transaction<R>(Future<R> Function(Transaction txn) action) =>
      db.transaction(action);

  Future<void> close() => db.close();
}
