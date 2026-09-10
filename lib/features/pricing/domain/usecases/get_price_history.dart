import '../../../../core/error/result.dart';
import '../entities/pricing.dart';
import '../repositories/pricing_repository.dart';

/// Every recorded change for one product, newest first. Read-only, so any role
/// that can see the catalogue may read it; the price-history *screen* is a
/// later (D2) feature behind `FeatureFlag.priceHistory`.
class GetPriceHistory {
  const GetPriceHistory({required this.repository});

  final PricingRepository repository;

  Future<Result<List<PriceChange>>> call(String productId) => repository.history(productId);
}
