import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/category.dart';
import '../repositories/category_repository.dart';
import '../validation.dart';

class RenameCategory {
  const RenameCategory({required this.repository, required this.session});

  final CategoryRepository repository;
  final SessionReader session;

  Future<Result<Category>> call(String id, String name) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    final validated = CategoryValidation.name(name);
    if (validated case Err<String>(:final failure)) return Err(failure);
    return repository.rename(id, validated.valueOrNull!);
  }
}
