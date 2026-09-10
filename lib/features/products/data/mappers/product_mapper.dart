import '../../../../core/database/schema/tables.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/product.dart';

/// Row ⇄ entity conversion (TECHNICAL_STRUCTURE §3, rule 3).
/// `currency` comes from the store — it is not stored per product.

Product productFromRow(Map<String, Object?> row, String currency) => Product(
      id: row['id']! as String,
      categoryId: row['category_id'] as String?,
      name: row['name']! as String,
      nameAlt: row['name_alt'] as String?,
      sku: row['sku'] as String?,
      barcode: row['barcode'] as String?,
      unit: ProductUnit.fromName((row['unit'] as String?) ?? ProductUnit.piece.name),
      cost: Money((row['cost_minor'] as int?) ?? 0, currency),
      price: Money((row['price_minor'] as int?) ?? 0, currency),
      reorderPoint: Quantity((row['reorder_point_milli'] as int?) ?? 0),
      isArchived: ((row['is_archived'] as int?) ?? 0) != 0,
      hasImage: ((row['has_image'] as int?) ?? 0) != 0,
      updatedAt: fromEpochMs((row['updated_at'] as int?) ?? 0),
    );

/// List row: product + its quantity and status at the current branch.
ProductSummary productSummaryFromRow(Map<String, Object?> row, String currency) {
  final product = productFromRow(row, currency);
  final qtyMilli = (row['qty_milli'] as int?) ?? 0;
  return ProductSummary(
    product: product,
    quantity: Quantity(qtyMilli),
    status: StockStatus.of(
      qtyMilli: qtyMilli,
      reorderPointMilli: product.reorderPoint.milli,
    ),
    categoryName: row['category_name'] as String?,
  );
}

/// Columns for a new product. `reorder_point_milli` is left at its default —
/// A4 owns that column (AGENT_PHASES §5.2).
Map<String, Object?> insertValuesFromDraft({
  required String id,
  required String storeId,
  required ProductDraft draft,
  required int nowMs,
}) =>
    {
      C.id: id,
      C.storeId: storeId,
      'category_id': draft.categoryId,
      'name': draft.name,
      'name_alt': draft.nameAlt,
      'sku': draft.sku,
      'barcode': draft.barcode,
      'unit': draft.unit.name,
      'cost_minor': draft.cost.minor,
      'price_minor': draft.price.minor,
      'is_archived': 0,
      C.createdAt: nowMs,
      C.updatedAt: nowMs,
    };

/// Columns an edit may change. Price and cost are owned by pricing (A3) and
/// are deliberately absent.
Map<String, Object?> updateValuesFromDraft(ProductDraft draft) => {
      'category_id': draft.categoryId,
      'name': draft.name,
      'name_alt': draft.nameAlt,
      'sku': draft.sku,
      'barcode': draft.barcode,
      'unit': draft.unit.name,
    };
