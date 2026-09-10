import '../../../../core/error/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/pricing.dart';

abstract interface class PricingRepository {
  Future<Result<void>> updatePrice(String productId, {required Money price, Money? cost});

  Future<Result<List<PriceChangePreview>>> previewBulk(BulkPriceRule rule);

  /// Applies atomically; returns the batch id shared by all `price_changes` rows.
  Future<Result<String>> applyBulk(BulkPriceRule rule);

  Future<Result<List<PriceChange>>> history(String productId);

  Future<Result<List<PriceChange>>> batch(String batchId);
}
