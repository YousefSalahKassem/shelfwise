import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../domain/repositories/store_repository.dart';
import '../datasources/store_local_data_source.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl({required this.local, required this.changes});

  final StoreLocalDataSource local;
  final DbChanges changes;

  @override
  Future<Result<Store?>> getCurrent() => _guard(local.findStore);

  @override
  Future<Result<Branch?>> getDefaultBranch() => _guard(() async {
        final store = await local.findStore();
        return store == null ? null : local.findDefaultBranch(store.id);
      });

  @override
  Future<Result<StoreSetup>> createStoreWithOwner({
    required String storeName,
    required String currency,
    required String locale,
    required String ownerName,
    required String pin,
  }) =>
      _guard(() async {
        if (await local.findStore() != null) {
          throw const _AlreadyOnboarded();
        }
        final (store, branch, owner) = await local.createStoreWithOwner(
          storeName: storeName,
          currency: currency,
          locale: locale,
          ownerName: ownerName,
          pin: pin,
        );
        changes.notify({DbTable.stores, DbTable.branches, DbTable.profiles});
        return StoreSetup(store: store, branch: branch, owner: owner);
      });

  @override
  Future<Result<Store>> updateStore({required String name, required String currency}) =>
      _guard(() async {
        final current = await local.findStore();
        if (current == null) throw const _NoStore();
        final store = await local.updateStore(id: current.id, name: name, currency: currency);
        changes.notify({DbTable.stores});
        return store;
      });

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on _AlreadyOnboarded {
      return const Err(ConflictFailure('store'));
    } on _NoStore {
      return const Err(NotFoundFailure('store'));
    } on Object catch (e) {
      return Err(StorageFailure('store repository', e));
    }
  }
}

class _AlreadyOnboarded implements Exception {
  const _AlreadyOnboarded();
}

class _NoStore implements Exception {
  const _NoStore();
}
