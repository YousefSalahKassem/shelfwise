import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/product.dart';

abstract interface class ProductRepository {
  /// Re-emits when products, stock levels or categories change.
  Stream<List<ProductSummary>> watch(ProductQuery query);

  Future<Result<int>> count(ProductQuery query);

  Future<Result<Product>> getById(String id);

  /// Null (in Success) when no product has this barcode.
  Future<Result<Product?>> findByBarcode(String barcode);

  /// [ConflictFailure] `barcode` / `sku` when already used in this store.
  Future<Result<Product>> create(ProductDraft draft);

  /// Ignores price/cost in [draft] (owned by pricing).
  Future<Result<Product>> update(String id, ProductDraft draft);

  Future<Result<void>> setArchived(String id, {required bool archived});

  /// JPEG bytes already resized by the caller; null removes the image.
  Future<Result<void>> setImage(String id, Uint8List? jpegBytes);

  Future<Uint8List?> image(String id);
}
