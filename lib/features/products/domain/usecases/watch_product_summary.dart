import '../entities/product.dart';
import '../repositories/product_detail_repository.dart';

/// One product with its current stock, for the detail screen.
class WatchProductSummary {
  const WatchProductSummary(this.repository);
  final ProductDetailRepository repository;

  Stream<ProductSummary?> call(String productId) => repository.watchSummary(productId);
}
