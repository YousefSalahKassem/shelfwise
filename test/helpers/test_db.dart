import 'package:shelfwise/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Fresh in-memory database with all migrations applied.
/// Use in `setUp` (not inside `testWidgets` bodies, which run in a fake-async zone).
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    singleInstance: false,
  );
}
