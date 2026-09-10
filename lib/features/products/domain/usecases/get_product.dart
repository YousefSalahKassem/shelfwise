import '../../../../core/error/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// One product, for the edit form.
class GetProduct {
  const GetProduct(this.repository);
  final ProductRepository repository;

  Future<Result<Product>> call(String id) => repository.getById(id);
}
