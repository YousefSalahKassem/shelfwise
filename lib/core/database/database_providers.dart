import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'app_database.dart';

part 'database_providers.g.dart';

/// Opened in `bootstrap.dart` and injected with `overrideWithValue`.
/// Tests override it with an in-memory database (test/helpers/test_db.dart).
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) =>
    throw UnimplementedError('appDatabaseProvider must be overridden in bootstrap');
