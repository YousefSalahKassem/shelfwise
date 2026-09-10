import 'package:freezed_annotation/freezed_annotation.dart';

part 'category.freezed.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    required String id,
    String? parentId,
    required String name,
    @Default(0) int sortOrder,
  }) = _Category;
}

/// A top-level category with its (max one level of) children.
@freezed
abstract class CategoryNode with _$CategoryNode {
  const factory CategoryNode({
    required Category category,
    @Default(<Category>[]) List<Category> children,
    @Default(0) int productCount,
  }) = _CategoryNode;
}
