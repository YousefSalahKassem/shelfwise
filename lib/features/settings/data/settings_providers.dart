import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/database/db_changes.dart';
import '../../../core/utils/core_providers.dart';
import '../domain/repositories/settings_repository.dart';
import 'datasources/settings_local_data_source.dart';
import 'repositories/settings_repository_impl.dart';

part 'settings_providers.g.dart';

/// The device settings store, or **null** when no database is available.
///
/// `bootstrap.dart` always provides one, so null only happens in widget tests
/// that don't override `appDatabaseProvider` (e.g. `test/helpers/test_app.dart`).
/// Preferences then stay in memory for the life of the test instead of every
/// screen crashing on a dependency it doesn't use. Riverpod wraps the original
/// `UnimplementedError` in a `ProviderException`, hence the broad catch.
@Riverpod(keepAlive: true)
SettingsRepository? settingsRepository(Ref ref) {
  try {
    return SettingsRepositoryImpl(
      local: SettingsLocalDataSource(
        db: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
      ),
      changes: ref.watch(dbChangesProvider),
    );
  } on Object {
    return null;
  }
}
