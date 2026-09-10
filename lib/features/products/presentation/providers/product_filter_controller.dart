import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/stock_status.dart';
import '../../domain/entities/product.dart';

part 'product_filter_controller.g.dart';

/// Rows fetched per page (brief: 50, infinite scroll).
const int productPageSize = 50;

/// Search text, filters, sort and how many rows are currently shown.
///
/// Paging grows `limit` instead of moving `offset`: one query always returns
/// every visible row, so a live `dbChanges` refresh can never duplicate or drop
/// an item while the user is scrolling.
@riverpod
class ProductFilterController extends _$ProductFilterController {
  @override
  ProductQuery build() => const ProductQuery(limit: productPageSize);

  void setSearch(String search) => _reset(state.copyWith(search: search));

  void setCategory(String? categoryId) => _reset(state.copyWith(categoryId: categoryId));

  void toggleStatus(StockStatus status) {
    final statuses = {...state.statuses};
    if (!statuses.remove(status)) statuses.add(status);
    _reset(state.copyWith(statuses: statuses));
  }

  void setSort(ProductSort sort) => _reset(state.copyWith(sort: sort));

  void setIncludeArchived({required bool value}) =>
      _reset(state.copyWith(includeArchived: value));

  void clear() => state = const ProductQuery(limit: productPageSize);

  /// Shows one more page.
  void loadMore() => state = state.copyWith(limit: state.limit + productPageSize);

  bool get hasFilters =>
      state.search.isNotEmpty ||
      state.categoryId != null ||
      state.statuses.isNotEmpty ||
      state.includeArchived;

  void _reset(ProductQuery next) => state = next.copyWith(limit: productPageSize);
}
