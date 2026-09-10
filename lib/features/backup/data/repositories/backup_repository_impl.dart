// OWNER: A6.
import 'dart:typed_data';

import '../../../../core/database/db_changes.dart';
import '../../../../core/database/migrations/migration.dart';
import '../../../../core/database/schema/tables.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../settings/public.dart';
import '../../domain/entities/backup_info.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_local_data_source.dart';
import '../models/backup_file.dart';
import '../models/usage_report.dart';

class BackupRepositoryImpl implements BackupRepository {
  const BackupRepositoryImpl({
    required BackupLocalDataSource local,
    required DbChanges changes,
    required Clock clock,
    required String brandId,
    required SessionReader Function() session,
    SettingsRepository? settings,
  }) : _local = local,
       _changes = changes,
       _clock = clock,
       _brandId = brandId,
       _session = session,
       _settings = settings;

  final BackupLocalDataSource _local;
  final DbChanges _changes;
  final Clock _clock;
  final String _brandId;
  final SessionReader Function() _session;
  final SettingsRepository? _settings;

  @override
  Future<Result<Uint8List>> create() async {
    try {
      final store = _session().store;
      final file = BackupFile(
        schemaVersion: await _local.schemaVersion(),
        brandId: _brandId,
        storeId: store?.id ?? '',
        storeName: store?.name ?? '',
        createdAt: _clock.now(),
        tables: await _local.dumpAll(),
      );
      return Success(file.encode());
    } on Object catch (e) {
      return Err(StorageFailure('backup create failed', e));
    }
  }

  @override
  Future<Result<BackupInfo>> inspect(Uint8List bytes) async {
    final parsed = _read(bytes);
    return parsed.map((file) => file.info);
  }

  @override
  Future<Result<void>> restore(Uint8List bytes) async {
    final BackupFile file;
    switch (_read(bytes)) {
      case Err<BackupFile>(:final failure):
        return Err<void>(failure);
      case Success<BackupFile>(:final value):
        file = value;
    }

    try {
      final upgraded = BackupUpgrades.apply(file.tables, file.schemaVersion);
      final rows = BackupFile(
        schemaVersion: file.schemaVersion,
        brandId: file.brandId,
        storeId: file.storeId,
        storeName: file.storeName,
        createdAt: file.createdAt,
        tables: upgraded,
      ).withColumns(await _local.liveColumns());

      await _local.replaceAll(rows.tables);
    } on Object catch (e) {
      // The whole restore is one transaction: on failure the device still
      // holds exactly what it held before.
      return Err<void>(StorageFailure('restore failed', e));
    }

    _changes.notify(DbTable.values.toSet());
    return ok;
  }

  @override
  Future<DateTime?> lastBackupAt() async {
    final stored = await _settings?.read(SettingKeys.lastBackupAt);
    final value = stored?.valueOrNull;
    final ms = value == null ? null : int.tryParse(value);
    return ms == null ? null : fromEpochMs(ms);
  }

  @override
  Future<Result<Uint8List>> exportUsage() async {
    try {
      final store = _session().store;
      return Success(
        buildUsageCsv(
          brandId: _brandId,
          storeId: store?.id ?? '',
          storeName: store?.name ?? '',
          generatedAt: _clock.now(),
          summary: await _local.summary(),
          events: await _local.events(),
        ),
      );
    } on Object catch (e) {
      return Err(StorageFailure('usage export failed', e));
    }
  }

  /// Parsing plus the two checks that make a *readable* file *restorable*:
  /// it belongs to this brand, and it isn't from a newer app version.
  Result<BackupFile> _read(Uint8List bytes) {
    final BackupFile file;
    try {
      file = BackupFile.parse(bytes);
    } on BackupFormatException catch (e) {
      return Err(ValidationFailure(field: 'file', code: e.code));
    } on Object catch (e) {
      return Err(StorageFailure('backup unreadable', e));
    }
    if (file.brandId != _brandId) {
      return const Err(
        ValidationFailure(field: 'file', code: 'brand_mismatch'),
      );
    }
    if (file.schemaVersion > latestSchemaVersion) {
      return const Err(ValidationFailure(field: 'file', code: 'newer_schema'));
    }
    if ((file.tables[T.stores] ?? const []).isEmpty) {
      return const Err(ValidationFailure(field: 'file', code: 'empty'));
    }
    return Success(file);
  }
}
