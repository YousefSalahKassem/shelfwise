// OWNER: A6.
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/file_service.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/backup_candidate.dart';
import '../entities/backup_info.dart';
import '../repositories/backup_repository.dart';

/// Step one of a restore: choose a file and read its header — the database is
/// not touched. The owner sees what the file holds before deciding.
class InspectBackup {
  const InspectBackup({
    required BackupRepository repository,
    required FileService files,
    required SessionReader Function() session,
  })  : _repository = repository,
        _files = files,
        _session = session;

  final BackupRepository _repository;
  final FileService _files;
  final SessionReader Function() _session;

  static const extensions = ['json'];

  /// Returns the chosen file, or **null** if the user cancelled the picker.
  Future<Result<BackupCandidate?>> call() async {
    if (!_session().can(Permission.backupRestore)) {
      return const Err(PermissionFailure('backupRestore'));
    }

    final PickedFile? picked;
    try {
      picked = await _files.pick(extensions: extensions);
    } on Object catch (e) {
      return Err(StorageFailure('backup pick failed', e));
    }
    if (picked == null) return const Success<BackupCandidate?>(null);

    switch (await _repository.inspect(picked.bytes)) {
      case Err<BackupInfo>(:final failure):
        return Err<BackupCandidate?>(failure);
      case Success<BackupInfo>(:final value):
        return Success<BackupCandidate?>(
          BackupCandidate(fileName: picked.name, bytes: picked.bytes, info: value),
        );
    }
  }
}
