import 'dart:typed_data';

import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../repositories/product_repository.dart';

/// Stores (or clears) the product thumbnail. The bytes are already a small
/// JPEG — resizing happens in the presentation layer, off the domain.
class SetProductImage {
  const SetProductImage({required this.repository, required this.session});

  final ProductRepository repository;
  final SessionReader session;

  Future<Result<void>> call(String id, Uint8List? jpegBytes) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    return repository.setImage(id, jpegBytes);
  }
}
