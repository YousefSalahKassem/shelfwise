import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/category_repository.dart';

/// Re-parents and/or re-orders a category. The repository enforces the
/// two-level rule; a category with children can only stay at the top level.
class MoveCategory {
  const MoveCategory({required this.repository, required this.session});

  final CategoryRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String id, {String? parentId, required int sortOrder}) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    if (sortOrder < 0) {
      return const Err(ValidationFailure(field: 'sortOrder', code: 'negative'));
    }
    return repository.move(id, parentId: parentId, sortOrder: sortOrder);
  }
}
