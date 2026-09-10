import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/category_repository.dart';

/// Deletes an empty category. Pass [moveProductsTo] to re-home its products
/// first; a category with sub-categories can never be deleted directly.
class DeleteCategory {
  const DeleteCategory({required this.repository, required this.session});

  final CategoryRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String id, {String? moveProductsTo}) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    return repository.delete(id, moveProductsTo: moveProductsTo);
  }
}
