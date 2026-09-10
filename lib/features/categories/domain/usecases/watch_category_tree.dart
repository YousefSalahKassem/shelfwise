import '../entities/category.dart';
import '../repositories/category_repository.dart';

/// Live two-level category tree. Reading needs no permission (everyone views).
class WatchCategoryTree {
  const WatchCategoryTree(this.repository);
  final CategoryRepository repository;

  Stream<List<CategoryNode>> call() => repository.watchTree();
}
