import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';

/// Everything created by first-run onboarding, in one transaction.
class StoreSetup {
  const StoreSetup({required this.store, required this.branch, required this.owner});
  final Store store;
  final Branch branch;
  final Profile owner;
}

abstract interface class StoreRepository {
  /// The store on this device, or null before onboarding.
  Future<Result<Store?>> getCurrent();

  Future<Result<Branch?>> getDefaultBranch();

  /// Creates store + default branch + owner profile (with hashed [pin]).
  Future<Result<StoreSetup>> createStoreWithOwner({
    required String storeName,
    required String currency,
    required String locale,
    required String ownerName,
    required String pin,
  });

  Future<Result<Store>> updateStore({required String name, required String currency});
}
