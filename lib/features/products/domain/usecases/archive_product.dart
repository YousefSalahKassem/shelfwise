import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/product_repository.dart';

/// Hides a product from the lists while keeping its history (never a delete).
class ArchiveProduct {
  const ArchiveProduct({required this.repository, required this.session});

  final ProductRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String id, {required bool archived}) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    return repository.setArchived(id, archived: archived);
  }
}
