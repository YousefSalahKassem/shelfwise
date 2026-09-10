// OWNER: A6 (replaces the W0 no-op stub).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../database/app_database.dart';
import '../../database/database_providers.dart';
import '../../database/db_changes.dart';
import '../../session/session_impl.dart';
import '../../utils/core_providers.dart';
import '../analytics_service.dart';
import 'db_analytics_service.dart';

part 'analytics_impl.g.dart';

/// The app writes events to `app_events`; widget tests that don't provide a
/// database get the no-op service instead of an error, because no screen
/// should depend on analytics being available.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) {
  final AppDatabase database;
  try {
    database = ref.watch(appDatabaseProvider);
  } on UnimplementedError {
    return const NoopAnalyticsService();
  }
  final service = DbAnalyticsService(
    database: database,
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGeneratorProvider),
    changes: ref.watch(dbChangesProvider),
    currentProfileId: () => ref.read(sessionControllerProvider).profile?.id,
  );
  ref.onDispose(service.flush);
  return service;
}
