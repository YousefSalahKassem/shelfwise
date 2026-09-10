// OWNER: A6.
import 'dart:typed_data';

import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/file_service.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../repositories/backup_repository.dart';
import '../services/backup_file_name.dart';

/// Saves this store's activation numbers and event log as a CSV the pilot team
/// collects at the weekly check-in (PLAN §7). Without sync this is how the
/// business-plan success measures leave the store.
class ExportUsage {
  const ExportUsage({
    required BackupRepository repository,
    required FileService files,
    required Clock clock,
    required String brandId,
    required SessionReader Function() session,
  })  : _repository = repository,
        _files = files,
        _clock = clock,
        _brandId = brandId,
        _session = session;

  final BackupRepository _repository;
  final FileService _files;
  final Clock _clock;
  final String _brandId;
  final SessionReader Function() _session;

  static const mimeType = 'text/csv';

  /// Returns the file name that was written, or **null** if the user cancelled.
  Future<Result<String?>> call() async {
    final session = _session();
    if (!session.can(Permission.backupRestore)) {
      return const Err(PermissionFailure('backupRestore'));
    }

    final Uint8List bytes;
    switch (await _repository.exportUsage()) {
      case Err<Uint8List>(:final failure):
        return Err<String?>(failure);
      case Success<Uint8List>(:final value):
        bytes = value;
    }

    final fileName = BackupFileName.usage(
      brandId: _brandId,
      storeName: session.store?.name ?? '',
      storeId: session.store?.id ?? '',
      at: _clock.now(),
    );
    try {
      final saved = await _files.save(fileName, bytes, mimeType: mimeType);
      return Success<String?>(saved ? fileName : null);
    } on Object catch (e) {
      return Err(StorageFailure('usage export save failed', e));
    }
  }
}
