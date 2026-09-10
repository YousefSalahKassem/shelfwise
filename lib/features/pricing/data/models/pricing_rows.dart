import '../../../../core/database/schema/tables.dart';

/// The columns pricing needs from `products`. Pricing writes only
/// `price_minor` / `cost_minor` (AGENT_PHASES §5.2); everything else is read.
class ProductPricingRow {
  const ProductPricingRow({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.costMinor,
  });

  factory ProductPricingRow.fromMap(Map<String, Object?> row) => ProductPricingRow(
        id: row[C.id]! as String,
        name: row[PriceColumns.name] as String? ?? '',
        priceMinor: row[PriceColumns.priceMinor] as int? ?? 0,
        costMinor: row[PriceColumns.costMinor] as int? ?? 0,
      );

  final String id;
  final String name;
  final int priceMinor;
  final int costMinor;
}

/// One product's new numbers, ready to be written by the data source.
class PriceChangeWrite {
  const PriceChangeWrite({
    required this.productId,
    required this.oldPriceMinor,
    required this.newPriceMinor,
    required this.oldCostMinor,
    required this.newCostMinor,
  });

  final String productId;
  final int oldPriceMinor;
  final int newPriceMinor;
  final int oldCostMinor;
  final int newCostMinor;

  bool get changesPrice => oldPriceMinor != newPriceMinor;
  bool get changesCost => oldCostMinor != newCostMinor;
  bool get isNoop => !changesPrice && !changesCost;
}

/// A category as the bulk screen needs it (id, name, parent).
class CategoryOptionRow {
  const CategoryOptionRow({required this.id, required this.name, this.parentId});

  factory CategoryOptionRow.fromMap(Map<String, Object?> row) => CategoryOptionRow(
        id: row[C.id]! as String,
        name: row[PriceColumns.name] as String? ?? '',
        parentId: row[PriceColumns.parentId] as String?,
      );

  final String id;
  final String name;
  final String? parentId;
}

/// Column names used by the pricing SQL (kept next to the rows that use them;
/// the shared ones live in [C] / [T]).
abstract final class PriceColumns {
  static const name = 'name';
  static const parentId = 'parent_id';
  static const categoryId = 'category_id';
  static const priceMinor = 'price_minor';
  static const costMinor = 'cost_minor';
  static const isArchived = 'is_archived';
  static const sortOrder = 'sort_order';
  static const oldPriceMinor = 'old_price_minor';
  static const newPriceMinor = 'new_price_minor';
  static const oldCostMinor = 'old_cost_minor';
  static const newCostMinor = 'new_cost_minor';
  static const batchId = 'batch_id';
}
