import '../../../../core/error/result.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// How many products match, ignoring paging — used for the result count and to
/// know whether another page exists.
class CountProducts {
  const CountProducts(this.repository);
  final ProductRepository repository;

  Future<Result<int>> call(ProductQuery query) => repository.count(query);
}
