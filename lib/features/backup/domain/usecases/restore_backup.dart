// OWNER: A6.
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/backup_candidate.dart';
import '../repositories/backup_repository.dart';

/// Step two of a restore: replace every table with the contents of a file the
/// owner has already seen a summary of and confirmed twice.
///
/// This is the only place in the app that writes outside its own feature's
/// tables (AGENT_PHASES §5.2). It is one transaction: either the device holds
/// the backup afterwards, or it is untouched.
///
/// The caller must restart the session afterwards — every profile id in the
/// database has just been replaced.
class RestoreBackup {
  const RestoreBackup({
    required BackupRepository repository,
    required SessionReader Function() session,
  })  : _repository = repository,
        _session = session;

  final BackupRepository _repository;
  final SessionReader Function() _session;

  Future<Result<void>> call(BackupCandidate candidate) async {
    if (!_session().can(Permission.backupRestore)) {
      return const Err(PermissionFailure('backupRestore'));
    }
    return _repository.restore(candidate.bytes);
  }
}
