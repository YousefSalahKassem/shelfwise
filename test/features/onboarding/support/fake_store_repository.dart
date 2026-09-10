import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/features/onboarding/domain/repositories/store_repository.dart';

/// In-memory [StoreRepository] for use-case and widget tests.
class FakeStoreRepository implements StoreRepository {
  FakeStoreRepository({this.store, this.branch});

  Store? store;
  Branch? branch;
  String? createdPin;
  Failure? failWith;

  @override
  Future<Result<Store?>> getCurrent() async => Success(store);

  @override
  Future<Result<Branch?>> getDefaultBranch() async => Success(branch);

  @override
  Future<Result<StoreSetup>> createStoreWithOwner({
    required String storeName,
    required String currency,
    required String locale,
    required String ownerName,
    required String pin,
  }) async {
    if (failWith case final failure?) return Err(failure);
    if (store != null) return const Err(ConflictFailure('store'));
    store = Store(id: 'store-1', name: storeName, currency: currency, locale: locale);
    branch = Branch(id: 'branch-1', storeId: 'store-1', name: storeName, isDefault: true);
    createdPin = pin;
    return Success(
      StoreSetup(
        store: store!,
        branch: branch!,
        owner: Profile(
          id: 'profile-owner',
          storeId: 'store-1',
          name: ownerName,
          role: Role.owner,
          locale: locale,
        ),
      ),
    );
  }

  @override
  Future<Result<Store>> updateStore({required String name, required String currency}) async {
    if (failWith case final failure?) return Err(failure);
    final current = store;
    if (current == null) return const Err(NotFoundFailure('store'));
    store = current.copyWith(name: name, currency: currency);
    return Success(store!);
  }
}
