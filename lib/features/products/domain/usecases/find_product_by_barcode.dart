import '../../../../core/error/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Scan-to-find. Success with null means "no product has this barcode" — the
/// caller then opens a new product form prefilled with the code.
class FindProductByBarcode {
  const FindProductByBarcode(this.repository);
  final ProductRepository repository;

  Future<Result<Product?>> call(String barcode) => repository.findByBarcode(barcode);
}
