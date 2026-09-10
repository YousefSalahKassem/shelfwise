import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Live product list for the current filters. Viewing needs no permission —
/// every role has `viewCatalogue` (TECHNICAL_STRUCTURE §10).
class WatchProducts {
  const WatchProducts(this.repository);
  final ProductRepository repository;

  Stream<List<ProductSummary>> call(ProductQuery query) => repository.watch(query);
}
