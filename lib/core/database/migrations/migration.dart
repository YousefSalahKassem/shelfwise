import 'package:sqflite_common/sqlite_api.dart';

import 'm001_initial.dart';

/// One schema step. Never edit a migration that has shipped — add a new one.
abstract class Migration {
  const Migration();
  int get version;
  Future<void> up(DatabaseExecutor db);
}

/// Ordered list of all migrations. The lead appends new ones (m002, m003…).
const List<Migration> allMigrations = [M001Initial()];

int get latestSchemaVersion => allMigrations.last.version;
