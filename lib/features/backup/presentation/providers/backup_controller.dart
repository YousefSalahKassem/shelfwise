// OWNER: A6.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/backup_candidate.dart';
import 'backup_providers.dart';

part 'backup_controller.g.dart';

/// What the backup screen is busy with, so buttons can be disabled and a
/// progress line shown. Restoring is the one the user must not interrupt.
enum BackupTask { idle, creating, choosing, restoring, exporting }

/// Runs the backup use cases one at a time. It returns each [Result] to the
/// screen instead of holding messages: the wording lives in the ARB file.
@riverpod
class BackupController extends _$BackupController {
  @override
  BackupTask build() => BackupTask.idle;

  bool get isBusy => state != BackupTask.idle;

  /// Saves a backup file. Success carries the file name, or null if the user
  /// cancelled the save dialog.
  Future<Result<String?>> createBackup() =>
      _run(BackupTask.creating, () => ref.read(createBackupProvider)());

  /// Picks a file and reads its header. Success carries null if the user
  /// cancelled the picker.
  Future<Result<BackupCandidate?>> chooseBackup() =>
      _run(BackupTask.choosing, () => ref.read(inspectBackupProvider)());

  /// Replaces every table. The caller restarts the session afterwards.
  Future<Result<void>> restore(BackupCandidate candidate) =>
      _run(BackupTask.restoring, () => ref.read(restoreBackupProvider)(candidate));

  /// Saves the pilot usage CSV. Success carries null if the user cancelled.
  Future<Result<String?>> exportUsage() =>
      _run(BackupTask.exporting, () => ref.read(exportUsageProvider)());

  Future<T> _run<T>(BackupTask task, Future<T> Function() action) async {
    state = task;
    try {
      return await action();
    } finally {
      // A restore invalidates half the provider graph; the screen may already
      // be gone by the time the work finishes.
      if (ref.mounted) state = BackupTask.idle;
    }
  }
}
