import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/session/session_impl.dart';
import '../../data/category_data_providers.dart';
import '../../domain/entities/category.dart';
import '../../domain/usecases/create_category.dart';
import '../../domain/usecases/delete_category.dart';
import '../../domain/usecases/move_category.dart';
import '../../domain/usecases/rename_category.dart';
import '../../domain/usecases/watch_category_tree.dart';

part 'category_providers.g.dart';

// ── Use cases ──────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
WatchCategoryTree watchCategoryTree(Ref ref) =>
    WatchCategoryTree(ref.watch(categoryRepositoryProvider));

@Riverpod(keepAlive: true)
CreateCategory createCategory(Ref ref) => CreateCategory(
      repository: ref.watch(categoryRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
RenameCategory renameCategory(Ref ref) => RenameCategory(
      repository: ref.watch(categoryRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
MoveCategory moveCategory(Ref ref) => MoveCategory(
      repository: ref.watch(categoryRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
DeleteCategory deleteCategory(Ref ref) => DeleteCategory(
      repository: ref.watch(categoryRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

// ── Queries ────────────────────────────────────────────────────────────────

/// Live two-level tree with product counts.
@riverpod
Stream<List<CategoryNode>> categoryTree(Ref ref) => ref.watch(watchCategoryTreeProvider)();

/// Flat list for pickers: parents followed by their children.
@riverpod
List<CategoryOption> categoryOptions(Ref ref) {
  final tree = ref.watch(categoryTreeProvider).value ?? const [];
  return [
    for (final node in tree) ...[
      CategoryOption(id: node.category.id, name: node.category.name, isChild: false),
      for (final child in node.children)
        CategoryOption(
          id: child.id,
          name: child.name,
          isChild: true,
          parentId: node.category.id,
          parentName: node.category.name,
        ),
    ],
  ];
}

/// One line of a category picker.
class CategoryOption {
  const CategoryOption({
    required this.id,
    required this.name,
    required this.isChild,
    this.parentId,
    this.parentName,
  });

  final String id;
  final String name;
  final bool isChild;
  final String? parentId;
  final String? parentName;

  /// `Dairy › Cheese` for sub-categories, `Dairy` for top-level ones.
  String get fullName => parentName == null ? name : '$parentName › $name';
}
