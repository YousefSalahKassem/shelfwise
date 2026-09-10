import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_data_source.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({required this.local, required this.changes});

  final SettingsLocalDataSource local;
  final DbChanges changes;

  @override
  Future<Result<Map<String, String>>> readAll() => _guard(local.readAll);

  @override
  Future<Result<String?>> read(String key) => _guard(() => local.read(key));

  @override
  Future<Result<void>> write(String key, String value) => _guard(() async {
        await local.write(key, value);
        changes.notify({DbTable.settings});
      });

  @override
  Future<Result<void>> remove(String key) => _guard(() async {
        await local.remove(key);
        changes.notify({DbTable.settings});
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on Object catch (e) {
      return Err(StorageFailure('settings repository', e));
    }
  }
}
