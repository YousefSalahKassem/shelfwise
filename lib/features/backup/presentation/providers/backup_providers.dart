// OWNER: A6. Dependency graph of the backup feature.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/brand/brand_providers.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/platform/file_service.dart';
import '../../../../core/platform/impl/platform_providers.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/utils/core_providers.dart';
import '../../../settings/public.dart';
import '../../data/datasources/backup_local_data_source.dart';
import '../../data/datasources/storage_persistence.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/repositories/backup_repository.dart';
import '../../domain/usecases/create_backup.dart';
import '../../domain/usecases/export_usage.dart';
import '../../domain/usecases/inspect_backup.dart';
import '../../domain/usecases/restore_backup.dart';

part 'backup_providers.g.dart';

/// Settings keys this feature persists. `last_backup_at` is already in A1's
/// [SettingKeys]; the rest live here until A1 adopts them (see the A6 report).
abstract final class BackupSettingKeys {
  /// `granted` / `denied` / `unsupported` — the browser's answer to
  /// `navigator.storage.persist()`.
  static const storagePersisted = 'storage_persisted';
}

@Riverpod(keepAlive: true)
BackupLocalDataSource backupLocalDataSource(Ref ref) =>
    BackupLocalDataSource(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
BackupRepository backupRepository(Ref ref) => BackupRepositoryImpl(
      local: ref.watch(backupLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
      clock: ref.watch(clockProvider),
      brandId: ref.watch(brandConfigProvider).id,
      session: () => ref.read(sessionControllerProvider),
      settings: ref.watch(settingsRepositoryProvider),
    );

@Riverpod(keepAlive: true)
CreateBackup createBackup(Ref ref) => CreateBackup(
      repository: ref.watch(backupRepositoryProvider),
      files: ref.watch(fileServiceProvider),
      analytics: ref.watch(analyticsServiceProvider),
      clock: ref.watch(clockProvider),
      brandId: ref.watch(brandConfigProvider).id,
      session: () => ref.read(sessionControllerProvider),
      settings: ref.watch(settingsRepositoryProvider),
    );

@Riverpod(keepAlive: true)
InspectBackup inspectBackup(Ref ref) => InspectBackup(
      repository: ref.watch(backupRepositoryProvider),
      files: ref.watch(fileServiceProvider),
      session: () => ref.read(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
RestoreBackup restoreBackup(Ref ref) => RestoreBackup(
      repository: ref.watch(backupRepositoryProvider),
      session: () => ref.read(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
ExportUsage exportUsage(Ref ref) => ExportUsage(
      repository: ref.watch(backupRepositoryProvider),
      files: ref.watch(fileServiceProvider),
      clock: ref.watch(clockProvider),
      brandId: ref.watch(brandConfigProvider).id,
      session: () => ref.read(sessionControllerProvider),
    );

/// When the last backup was made, refreshed as soon as one is saved.
@riverpod
Stream<DateTime?> lastBackup(Ref ref) {
  final repository = ref.watch(backupRepositoryProvider);
  return watchQuery(ref.watch(dbChangesProvider), {DbTable.settings}, repository.lastBackupAt);
}

/// Asks the browser once per app start to keep this origin's data, and
/// remembers the answer (TECHNICAL_STRUCTURE §6). A no-op off the web.
@Riverpod(keepAlive: true)
Future<StoragePersistence> storagePersistence(Ref ref) async {
  final result = await requestStoragePersistence();
  try {
    await ref.read(settingsRepositoryProvider)?.write(
          BackupSettingKeys.storagePersisted,
          result.name,
        );
  } on Object {
    // Remembering the answer is a convenience; failing to must not hide it.
  }
  return result;
}

/// True when there is a database to back up. Screens outside this feature
/// (the dashboard banner) may build before one exists in a widget test.
@Riverpod(keepAlive: true)
bool backupAvailable(Ref ref) {
  try {
    ref.watch(appDatabaseProvider);
    return true;
  } on UnimplementedError {
    return false;
  }
}
