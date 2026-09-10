import '../../../../core/error/result.dart';
import '../entities/category.dart';

abstract interface class CategoryRepository {
  /// Two-level tree ordered by sortOrder, then name.
  Stream<List<CategoryNode>> watchTree();

  Future<Result<Category>> create(String name, {String? parentId});

  Future<Result<Category>> rename(String id, String name);

  /// Change parent (null = top level) and/or position. Max depth 2.
  Future<Result<void>> move(String id, {String? parentId, required int sortOrder});

  /// Only when empty; otherwise [ValidationFailure] code `not_empty`.
  /// Pass [moveProductsTo] to move products first.
  Future<Result<void>> delete(String id, {String? moveProductsTo});
}
