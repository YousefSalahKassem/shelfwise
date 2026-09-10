import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/money.dart';

part 'pricing.freezed.dart';

@freezed
sealed class PriceAdjustment with _$PriceAdjustment {
  /// +10 → 10% increase, -5 → 5% decrease.
  const factory PriceAdjustment.percent(double percent) = PercentAdjustment;

  /// Adds (or subtracts, if negative) a fixed amount.
  const factory PriceAdjustment.fixed(Money amount) = FixedAdjustment;
}

enum PriceTarget { price, cost, both }

@freezed
abstract class BulkPriceRule with _$BulkPriceRule {
  const factory BulkPriceRule({
    /// Either a category…
    String? categoryId,
    @Default(true) bool includeSubcategories,
    /// …or an explicit selection (used when non-empty).
    @Default(<String>[]) List<String> productIds,
    required PriceAdjustment adjustment,
    @Default(PriceTarget.price) PriceTarget target,
    @Default(RoundingStep.none) RoundingStep rounding,
    @Default(RoundingMode.nearest) RoundingMode roundingMode,
  }) = _BulkPriceRule;
}

@freezed
abstract class PriceChangePreview with _$PriceChangePreview {
  const factory PriceChangePreview({
    required String productId,
    required String productName,
    required Money oldPrice,
    required Money newPrice,
    required Money oldCost,
    required Money newCost,
  }) = _PriceChangePreview;

  const PriceChangePreview._();

  bool get belowCost => newPrice < newCost;
  bool get isZero => newPrice.isZero;
}

@freezed
abstract class PriceChange with _$PriceChange {
  const factory PriceChange({
    required String id,
    required String productId,
    required Money oldPrice,
    required Money newPrice,
    Money? oldCost,
    Money? newCost,
    String? batchId,
    required String profileId,
    required DateTime createdAt,
  }) = _PriceChange;
}
