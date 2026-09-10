/// Stock state of a product at a branch.
/// `low` = at or below the reorder point, `out` = zero or less.
enum StockStatus {
  ok,
  low,
  out;

  static StockStatus of({required int qtyMilli, required int reorderPointMilli}) {
    if (qtyMilli <= 0) return StockStatus.out;
    if (reorderPointMilli > 0 && qtyMilli <= reorderPointMilli) return StockStatus.low;
    return StockStatus.ok;
  }
}
