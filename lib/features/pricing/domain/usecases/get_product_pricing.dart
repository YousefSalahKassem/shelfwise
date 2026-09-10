import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/pricing.dart';
import '../repositories/pricing_repository.dart';

/// Current name, price and cost of one product, for the single-price screen.
///
/// Reuses [PricingRepository.previewBulk] with a no-op rule so pricing needs no
/// extra contract method and no dependency on the catalogue's repository.
class GetProductPricing {
  const GetProductPricing({required this.repository, required this.session});

  final PricingRepository repository;
  final SessionReader session;

  Future<Result<PriceChangePreview>> call(String productId) async {
    if (!session.can(Permission.editPrices)) {
      return const Err<PriceChangePreview>(PermissionFailure('editPrices'));
    }
    final result = await repository.previewBulk(
      BulkPriceRule(
        productIds: [productId],
        adjustment: const PriceAdjustment.percent(0),
      ),
    );
    return switch (result) {
      Err<List<PriceChangePreview>>(:final failure) => Err<PriceChangePreview>(failure),
      Success<List<PriceChangePreview>>(:final value) => value.isEmpty
          ? Err<PriceChangePreview>(NotFoundFailure('product', productId))
          : Success<PriceChangePreview>(value.first),
    };
  }
}
