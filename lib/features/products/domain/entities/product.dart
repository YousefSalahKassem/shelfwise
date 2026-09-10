import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';

part 'product.freezed.dart';

@freezed
abstract class Product with _$Product {
  const factory Product({
    required String id,
    String? categoryId,
    required String name,
    String? nameAlt,
    String? sku,
    String? barcode,
    @Default(ProductUnit.piece) ProductUnit unit,
    required Money cost,
    required Money price,
    required Quantity reorderPoint,
    @Default(false) bool isArchived,
    @Default(false) bool hasImage,
    required DateTime updatedAt,
  }) = _Product;
}

/// Input for create/update. Price & cost are only set here on create —
/// later changes go through pricing (A3).
@freezed
abstract class ProductDraft with _$ProductDraft {
  const factory ProductDraft({
    String? categoryId,
    required String name,
    String? nameAlt,
    String? sku,
    String? barcode,
    @Default(ProductUnit.piece) ProductUnit unit,
    required Money cost,
    required Money price,
  }) = _ProductDraft;
}

/// Row in lists: product + current stock at the current branch.
@freezed
abstract class ProductSummary with _$ProductSummary {
  const factory ProductSummary({
    required Product product,
    required Quantity quantity,
    required StockStatus status,
    String? categoryName,
  }) = _ProductSummary;
}

enum ProductSort { name, recentlyUpdated }

@freezed
abstract class ProductQuery with _$ProductQuery {
  const factory ProductQuery({
    /// Matches name, nameAlt, SKU or barcode.
    @Default('') String search,
    String? categoryId,
    /// Include products of sub-categories of [categoryId].
    @Default(true) bool includeSubcategories,
    /// Empty = any status.
    @Default(<StockStatus>{}) Set<StockStatus> statuses,
    @Default(false) bool includeArchived,
    @Default(ProductSort.name) ProductSort sort,
    @Default(50) int limit,
    @Default(0) int offset,
  }) = _ProductQuery;
}
