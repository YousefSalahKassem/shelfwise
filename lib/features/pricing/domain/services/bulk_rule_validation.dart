import '../../../../core/error/failure.dart';
import '../../../../core/utils/money.dart';
import '../entities/pricing.dart';
import 'price_calculator.dart';

/// Checks a [BulkPriceRule] before it reaches the database. Returns null when
/// the rule is usable, otherwise the failure to show the owner.
///
/// [currency] is the store currency: a fixed adjustment in another currency is
/// rejected rather than thrown at by [Money].
Failure? validateBulkRule(
  BulkPriceRule rule, {
  required String currency,
  bool requireChange = true,
}) {
  if (rule.productIds.isEmpty && (rule.categoryId == null || rule.categoryId!.isEmpty)) {
    return const ValidationFailure(field: 'scope', code: 'empty');
  }
  final adjustment = rule.adjustment;
  if (adjustment is FixedAdjustment && adjustment.amount.currency != currency) {
    return const ValidationFailure(field: 'amount', code: 'currency_mismatch');
  }
  if (adjustment is PercentAdjustment && !adjustment.percent.isFinite) {
    return const ValidationFailure(field: 'amount', code: 'invalid');
  }
  if (requireChange && adjustment.isNoop && rule.rounding == RoundingStep.none) {
    return const ValidationFailure(field: 'amount', code: 'no_change');
  }
  return null;
}
