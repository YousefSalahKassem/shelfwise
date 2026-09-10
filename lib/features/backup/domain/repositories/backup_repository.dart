import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/backup_info.dart';

abstract interface class BackupRepository {
  /// Full JSON backup of every table.
  Future<Result<Uint8List>> create();

  /// Reads the header without changing anything.
  Future<Result<BackupInfo>> inspect(Uint8List bytes);

  /// Replaces all data in one transaction (migrating older schemas first).
  Future<Result<void>> restore(Uint8List bytes);

  Future<DateTime?> lastBackupAt();

  /// CSV of `app_events` + activation summary for pilot check-ins.
  Future<Result<Uint8List>> exportUsage();
}
