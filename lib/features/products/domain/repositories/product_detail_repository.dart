import '../entities/product.dart';

/// A2 addition to the W0 contracts (a new file, no frozen file was changed):
/// the product detail screen needs one product **with its current stock**, and
/// `ProductRepository` only exposes list queries.
///
/// The A2 report asks the lead to fold `watchSummary` into `ProductRepository`
/// between waves; until then it is a separate interface, implemented by the
/// same repository object.
abstract interface class ProductDetailRepository {
  /// Re-emits when the product, its image, its category or its stock changes.
  /// Emits null when the product doesn't exist (or was deleted).
  Stream<ProductSummary?> watchSummary(String productId);
}
