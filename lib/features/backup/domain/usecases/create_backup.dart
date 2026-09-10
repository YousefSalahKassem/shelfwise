// OWNER: A6.
import 'dart:typed_data';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/file_service.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../settings/public.dart';
import '../repositories/backup_repository.dart';
import '../services/backup_file_name.dart';

/// Writes every table to a file the owner keeps outside the device.
///
/// Backup is a core feature in every tier, so there is no [FeatureFlag] check
/// here — only the owner-only [Permission.backupRestore].
///
/// The "last backup" date is recorded **after** the file is actually saved:
/// a cancelled save must not silence the reminder banner.
class CreateBackup {
  const CreateBackup({
    required BackupRepository repository,
    required FileService files,
    required AnalyticsService analytics,
    required Clock clock,
    required String brandId,
    required SessionReader Function() session,
    SettingsRepository? settings,
  })  : _repository = repository,
        _files = files,
        _analytics = analytics,
        _clock = clock,
        _brandId = brandId,
        _session = session,
        _settings = settings;

  final BackupRepository _repository;
  final FileService _files;
  final AnalyticsService _analytics;
  final Clock _clock;
  final String _brandId;
  final SessionReader Function() _session;

  /// Null only in tests without a database; the date is then not persisted.
  final SettingsRepository? _settings;

  static const mimeType = 'application/json';

  /// Returns the file name that was written, or **null** if the user cancelled
  /// the save dialog.
  Future<Result<String?>> call() async {
    final session = _session();
    if (!session.can(Permission.backupRestore)) {
      return const Err(PermissionFailure('backupRestore'));
    }

    final Uint8List bytes;
    switch (await _repository.create()) {
      case Err<Uint8List>(:final failure):
        return Err<String?>(failure);
      case Success<Uint8List>(:final value):
        bytes = value;
    }

    final now = _clock.now();
    final fileName = BackupFileName.backup(
      brandId: _brandId,
      storeName: session.store?.name ?? '',
      storeId: session.store?.id ?? '',
      at: now,
    );

    final bool saved;
    try {
      saved = await _files.save(fileName, bytes, mimeType: mimeType);
    } on Object catch (e) {
      return Err(StorageFailure('backup save failed', e));
    }
    if (!saved) return const Success<String?>(null);

    await _settings?.write(SettingKeys.lastBackupAt, '${now.epochMs}');
    await _analytics.log(AppEvent.backupCreated, {
      'size_bytes': bytes.length,
      'file_name': fileName,
    });
    return Success<String?>(fileName);
  }
}
