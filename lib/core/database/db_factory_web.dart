import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<DatabaseFactory> createDatabaseFactory() async => databaseFactoryFfiWeb;

/// On web the "path" is just the IndexedDB database name (isolated per origin,
/// i.e. per brand site).
Future<String> databasePath(String fileName) async => fileName;
