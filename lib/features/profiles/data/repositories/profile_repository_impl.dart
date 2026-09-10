import '../../../../core/auth/permission.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/value_objects/pin.dart';
import '../datasources/profile_local_data_source.dart';

/// Hashing and storage only. The brute-force cooldown lives one layer up, in
/// `UnlockProfile`, so the lock screen can show the remaining seconds.
class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({required this.local, required this.changes});

  final ProfileLocalDataSource local;
  final DbChanges changes;

  @override
  Stream<List<Profile>> watchAll() => watchQuery(changes, {DbTable.profiles}, local.findAll);

  @override
  Future<Result<Profile>> create({
    required String name,
    required Role role,
    required String pin,
    String? locale,
  }) =>
      _guard(() async {
        final storeId = await local.currentStoreId();
        if (storeId == null) throw const _NoStore();
        final profile = await local.insert(
          storeId: storeId,
          name: name,
          role: role,
          pin: pin,
          locale: locale,
        );
        changes.notify({DbTable.profiles});
        return profile;
      });

  @override
  Future<Result<Profile>> update(Profile profile) => _guard(() async {
        await local.updateDetails(profile);
        changes.notify({DbTable.profiles});
        return profile;
      });

  @override
  Future<Result<void>> resetPin(String profileId, String newPin) => _guard(() async {
        await local.updatePin(profileId, newPin);
        changes.notify({DbTable.profiles});
      });

  @override
  Future<Result<void>> deactivate(String profileId) => _guard(() async {
        await local.setActive(profileId, active: false);
        changes.notify({DbTable.profiles});
      });

  @override
  Future<Result<Profile>> verifyPin(String profileId, String pin) => _guard(() async {
        final profile = await local.findById(profileId);
        if (profile == null || !profile.isActive) throw const _WrongPin();
        final credentials = await local.findCredentials(profileId);
        if (credentials == null ||
            !local.hasher.verify(pin: pin, hash: credentials.hash, salt: credentials.salt)) {
          throw const _WrongPin();
        }
        return profile;
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on _WrongPin {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.wrongPin));
    } on _NoStore {
      return const Err(NotFoundFailure('store'));
    } on StateError catch (e) {
      return Err(NotFoundFailure('profile', e.message));
    } on Object catch (e) {
      return Err(StorageFailure('profile repository', e));
    }
  }
}

class _WrongPin implements Exception {
  const _WrongPin();
}

class _NoStore implements Exception {
  const _NoStore();
}
