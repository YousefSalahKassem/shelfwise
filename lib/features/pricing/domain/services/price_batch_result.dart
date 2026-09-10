import '../entities/pricing.dart';

/// Outcome of one bulk update: the batch id every `price_changes` row shares,
/// the rows themselves and the numbers shown on the summary screen.
class PriceBatchResult {
  const PriceBatchResult({required this.batchId, required this.changes});

  final String batchId;
  final List<PriceChange> changes;

  int get count => changes.length;

  /// Mean price change in percent, over the products whose old price was
  /// greater than zero. Null when there is nothing to average.
  double? get averagePercent {
    var sum = 0.0;
    var n = 0;
    for (final c in changes) {
      if (c.oldPrice.isZero) continue;
      sum += (c.newPrice.minor - c.oldPrice.minor) * 100 / c.oldPrice.minor;
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  int get increased => changes.where((c) => c.newPrice > c.oldPrice).length;
  int get decreased => changes.where((c) => c.newPrice < c.oldPrice).length;
}
