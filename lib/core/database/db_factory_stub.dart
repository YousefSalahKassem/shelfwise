import 'package:sqflite_common/sqlite_api.dart';

Future<DatabaseFactory> createDatabaseFactory() =>
    throw UnsupportedError('No database factory for this platform');

Future<String> databasePath(String fileName) =>
    throw UnsupportedError('No database path for this platform');
