import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../profiles/domain/value_objects/pin.dart';
import '../repositories/store_repository.dart';

/// First run: creates the store, its default branch and the owner profile in
/// one transaction (AGENT_PHASES §7.8). No permission check — nobody is signed
/// in yet, and the repository refuses a second store on the same device.
class CreateStore {
  const CreateStore({required this.repository, required this.analytics});

  final StoreRepository repository;
  final AnalyticsService analytics;

  Future<Result<StoreSetup>> call({
    required String storeName,
    required String currency,
    required String locale,
    required String ownerName,
    required String pin,
  }) async {
    final name = storeName.trim();
    if (name.isEmpty) {
      return const Err(ValidationFailure(field: 'storeName', code: 'required'));
    }
    final owner = ownerName.trim();
    if (owner.isEmpty) {
      return const Err(ValidationFailure(field: 'ownerName', code: 'required'));
    }
    if (!Pin.isValid(pin)) {
      return const Err(ValidationFailure(field: 'pin', code: PinFailureCodes.length));
    }

    final result = await repository.createStoreWithOwner(
      storeName: name,
      currency: currency,
      locale: locale,
      ownerName: owner,
      pin: pin,
    );
    if (result.isSuccess) {
      await analytics.log(AppEvent.storeCreated, {
        'currency': currency,
        'locale': locale,
      });
    }
    return result;
  }
}
