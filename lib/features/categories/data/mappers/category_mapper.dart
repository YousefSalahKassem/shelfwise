import '../../domain/entities/category.dart';

/// Row ⇄ entity conversion. Entities never carry DB column names.
Category categoryFromRow(Map<String, Object?> row) => Category(
      id: row['id']! as String,
      parentId: row['parent_id'] as String?,
      name: row['name']! as String,
      sortOrder: (row['sort_order'] as int?) ?? 0,
    );

/// Builds the two-level tree from a flat, already ordered list of rows.
/// Children whose parent is missing are promoted to the top level so nothing
/// disappears from the UI.
List<CategoryNode> categoryTreeFromRows(List<Map<String, Object?>> rows) {
  final parents = <String, _Pending>{};
  final orphans = <_Pending>[];
  final children = <String, List<Category>>{};

  for (final row in rows) {
    final category = categoryFromRow(row);
    final count = (row['product_count'] as int?) ?? 0;
    if (category.parentId == null) {
      parents[category.id] = _Pending(category, count);
    } else {
      orphans.add(_Pending(category, count));
    }
  }
  for (final child in orphans) {
    final parentId = child.category.parentId!;
    if (parents.containsKey(parentId)) {
      (children[parentId] ??= []).add(child.category);
    } else {
      parents[child.category.id] = _Pending(child.category.copyWith(parentId: null), child.productCount);
    }
  }
  return [
    for (final p in parents.values)
      CategoryNode(
        category: p.category,
        children: children[p.category.id] ?? const [],
        productCount: p.productCount,
      ),
  ];
}

class _Pending {
  const _Pending(this.category, this.productCount);
  final Category category;
  final int productCount;
}
