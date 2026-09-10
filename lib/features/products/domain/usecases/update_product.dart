import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';
import '../validation/product_validation.dart';

/// Edits a product. Price and cost in the draft are ignored — pricing (A3)
/// owns `price_minor` / `cost_minor` after creation.
class UpdateProduct {
  const UpdateProduct({required this.repository, required this.session});

  final ProductRepository repository;
  final SessionReader session;

  Future<Result<Product>> call(String id, ProductDraft draft) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    final normalized = ProductValidation.normalize(draft);
    if (normalized case Err<ProductDraft>(:final failure)) return Err(failure);
    return repository.update(id, normalized.valueOrNull!);
  }
}
