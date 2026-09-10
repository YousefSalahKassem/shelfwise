import '../../../../core/database/app_database.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/utils/clock.dart';

/// The only place with SQL for the `settings` table.
class SettingsLocalDataSource {
  SettingsLocalDataSource({required this.db, required this.clock});

  final AppDatabase db;
  final Clock clock;

  Future<Map<String, String>> readAll() async {
    final rows = await db.db.query(
      T.settings,
      columns: ['key', 'value'],
      where: '${C.deletedAt} IS NULL',
    );
    return {for (final row in rows) row['key']! as String: row['value']! as String};
  }

  Future<String?> read(String key) async {
    final rows = await db.db.query(
      T.settings,
      columns: ['value'],
      where: 'key = ? AND ${C.deletedAt} IS NULL',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> write(String key, String value) async {
    final now = clock.now().epochMs;
    await db.db.rawInsert(
      'INSERT INTO ${T.settings} (key, value, ${C.createdAt}, ${C.updatedAt}, ${C.deletedAt}) '
      'VALUES (?, ?, ?, ?, NULL) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
      '${C.updatedAt} = excluded.${C.updatedAt}, ${C.deletedAt} = NULL',
      [key, value, now, now],
    );
  }

  /// Soft delete, so a later sync can replay the removal (AD-2).
  Future<void> remove(String key) async {
    final now = clock.now().epochMs;
    await db.db.update(
      T.settings,
      {C.deletedAt: now, C.updatedAt: now},
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
