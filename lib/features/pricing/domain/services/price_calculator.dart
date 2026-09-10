import '../../../../core/utils/money.dart';
import '../entities/pricing.dart';

/// Pure price math shared by preview and apply, so an owner always gets exactly
/// what the preview showed. Money stays in integer minor units throughout
/// (TECHNICAL_STRUCTURE §6) — no doubles anywhere in the chain.
abstract final class PriceCalculator {
  /// New price and cost for one product under [rule].
  ///
  /// - The adjustment hits only what [BulkPriceRule.target] selects.
  /// - Rounding applies to the **price** only; a cost is never rounded.
  /// - A result below zero is clamped to zero (prices are never negative).
  static ({Money price, Money cost}) apply({
    required BulkPriceRule rule,
    required Money price,
    required Money cost,
  }) {
    final newPrice = rule.target == PriceTarget.cost
        ? price
        : _clamp(
            adjust(price, rule.adjustment).roundTo(rule.rounding, mode: rule.roundingMode),
          );
    final newCost =
        rule.target == PriceTarget.price ? cost : _clamp(adjust(cost, rule.adjustment));
    return (price: newPrice, cost: newCost);
  }

  /// [value] with [adjustment] applied, before rounding or clamping.
  static Money adjust(Money value, PriceAdjustment adjustment) => switch (adjustment) {
        PercentAdjustment(:final percent) => value.applyPercent(percent),
        FixedAdjustment(:final amount) => value + amount,
      };

  static Money _clamp(Money value) => value.isNegative ? Money.zero(value.currency) : value;
}

extension PriceAdjustmentX on PriceAdjustment {
  /// Value logged as the `mode` prop of `bulk_price_updated`.
  String get modeName => switch (this) {
        PercentAdjustment() => 'percent',
        FixedAdjustment() => 'fixed',
      };

  /// True when the adjustment would leave every product untouched.
  bool get isNoop => switch (this) {
        PercentAdjustment(:final percent) => percent == 0,
        FixedAdjustment(:final amount) => amount.isZero,
      };
}
