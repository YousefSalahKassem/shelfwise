import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/money.dart';
import '../repositories/pricing_repository.dart';

/// Changes one product's price (and optionally its cost), recording a
/// `price_changes` row. Owner only — staff calling this gets a
/// [PermissionFailure] even if they reached the screen another way.
class UpdatePrice {
  const UpdatePrice({required this.repository, required this.session});

  final PricingRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String productId, {required Money price, Money? cost}) async {
    if (!session.can(Permission.editPrices)) {
      return const Err<void>(PermissionFailure('editPrices'));
    }
    if (productId.isEmpty) {
      return const Err<void>(ValidationFailure(field: 'productId', code: 'empty'));
    }
    if (price.isNegative) {
      return const Err<void>(ValidationFailure(field: 'price', code: 'negative'));
    }
    if (cost != null && cost.isNegative) {
      return const Err<void>(ValidationFailure(field: 'cost', code: 'negative'));
    }
    final currency = session.store?.currency;
    if (currency != null && price.currency != currency) {
      return const Err<void>(ValidationFailure(field: 'price', code: 'currency_mismatch'));
    }
    if (currency != null && cost != null && cost.currency != currency) {
      return const Err<void>(ValidationFailure(field: 'cost', code: 'currency_mismatch'));
    }
    return repository.updatePrice(productId, price: price, cost: cost);
  }
}
