import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../validation.dart';

/// Adds a category, optionally under [parentId] (max depth 2).
/// No analytics event exists for categories — pilot metrics track products.
class CreateCategory {
  const CreateCategory({required this.repository, required this.session});

  final CategoryRepository repository;
  final SessionReader session;

  Future<Result<Category>> call(String name, {String? parentId}) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    final validated = CategoryValidation.name(name);
    if (validated case Err<String>(:final failure)) return Err(failure);
    return repository.create(validated.valueOrNull!, parentId: parentId);
  }
}
