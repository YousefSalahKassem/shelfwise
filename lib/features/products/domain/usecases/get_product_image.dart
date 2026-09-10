import 'dart:typed_data';

import '../repositories/product_repository.dart';

/// Thumbnail bytes for a product, or null when it has no photo.
class GetProductImage {
  const GetProductImage(this.repository);
  final ProductRepository repository;

  Future<Uint8List?> call(String id) => repository.image(id);
}
