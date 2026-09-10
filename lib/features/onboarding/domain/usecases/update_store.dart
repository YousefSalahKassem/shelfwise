import '../../../../core/auth/permission.dart';
import '../../../../core/brand/brand_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/store_repository.dart';

/// Owner-only edit of the store name and currency (settings screen).
class UpdateStore {
  const UpdateStore({required this.repository, required this.session});

  final StoreRepository repository;
  final SessionReader session;

  Future<Result<Store>> call({required String name, required String currency}) async {
    if (!session.can(Permission.manageSettings)) {
      return const Err(PermissionFailure('manageSettings'));
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(ValidationFailure(field: 'storeName', code: 'required'));
    }
    if (!BrandConfig.supportedCurrencies.contains(currency)) {
      return const Err(ValidationFailure(field: 'currency', code: 'unsupported'));
    }
    return repository.updateStore(name: trimmed, currency: currency);
  }
}
