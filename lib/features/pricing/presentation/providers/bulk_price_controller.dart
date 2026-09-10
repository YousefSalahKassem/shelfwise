import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/utils/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/pricing.dart';
import '../../domain/services/price_batch_result.dart';
import 'pricing_providers.dart';

part 'bulk_price_controller.freezed.dart';
part 'bulk_price_controller.g.dart';

/// `a,b,c` → `['a', 'b', 'c']`, ignoring blanks.
List<String> parseProductIds(String raw) => [
      for (final id in raw.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ];

/// Which screen of the bulk flow is showing.
enum BulkPhase { form, preview, done }

/// Percent or fixed amount — the two shapes of [PriceAdjustment].
enum BulkMode { percent, fixed }

/// What the bulk update is applied to.
enum BulkScope { category, selection }

@freezed
abstract class BulkPriceState with _$BulkPriceState {
  const factory BulkPriceState({
    /// Screen open time — the `bulk_price_updated` duration starts here.
    required DateTime startedAt,
    @Default(BulkPhase.form) BulkPhase phase,
    @Default(BulkScope.category) BulkScope scope,
    String? categoryId,
    @Default(true) bool includeSubcategories,
    @Default(<String>[]) List<String> productIds,
    @Default(BulkMode.percent) BulkMode mode,
    @Default(true) bool increase,
    @Default('') String amountText,
    @Default(PriceTarget.price) PriceTarget target,
    @Default(RoundingStep.none) RoundingStep rounding,
    @Default(RoundingMode.nearest) RoundingMode roundingMode,
    @Default(<PriceChangePreview>[]) List<PriceChangePreview> preview,
    @Default(false) bool busy,
    Failure? failure,
    /// Set to a validation code when the form itself is wrong (no scope,
    /// no amount) so the screen can point at the right field.
    String? formError,
    PriceBatchResult? result,
  }) = _BulkPriceState;

  const BulkPriceState._();

  bool get hasScope => scope == BulkScope.category
      ? (categoryId != null && categoryId!.isNotEmpty)
      : productIds.isNotEmpty;

  List<PriceChangePreview> get changed =>
      [for (final p in preview) if (p.newPrice != p.oldPrice || p.newCost != p.oldCost) p];

  int get belowCostCount => changed.where((p) => p.belowCost).length;
  int get zeroCount => changed.where((p) => p.isZero).length;
}

/// Drives the bulk repricing screen: form → preview → apply → summary.
///
/// [initialIds] is the raw `?ids=a,b` query parameter, so the catalogue can
/// link into a ready-made selection. Empty means "start on the category scope".
@riverpod
class BulkPriceController extends _$BulkPriceController {
  @override
  BulkPriceState build(String initialIds) {
    final ids = parseProductIds(initialIds);
    return BulkPriceState(
      startedAt: ref.read(clockProvider).now(),
      scope: ids.isEmpty ? BulkScope.category : BulkScope.selection,
      productIds: ids,
    );
  }

  String get _currency => ref.read(sessionControllerProvider).store?.currency ?? '';

  void setScope(BulkScope scope) => state = state.copyWith(scope: scope, phase: BulkPhase.form);

  void setCategory(String? categoryId) =>
      state = state.copyWith(categoryId: categoryId, formError: null);

  void setIncludeSubcategories(bool value) =>
      state = state.copyWith(includeSubcategories: value);

  void setProductIds(List<String> ids) =>
      state = state.copyWith(productIds: List.unmodifiable(ids), formError: null);

  void addProduct(String id) {
    if (state.productIds.contains(id)) return;
    setProductIds([...state.productIds, id]);
  }

  void setMode(BulkMode mode) => state = state.copyWith(mode: mode, formError: null);

  void setIncrease(bool increase) => state = state.copyWith(increase: increase);

  void setAmountText(String text) => state = state.copyWith(amountText: text, formError: null);

  void setTarget(PriceTarget target) => state = state.copyWith(target: target);

  void setRounding(RoundingStep step) => state = state.copyWith(rounding: step);

  void setRoundingMode(RoundingMode mode) => state = state.copyWith(roundingMode: mode);

  void backToForm() =>
      state = state.copyWith(phase: BulkPhase.form, preview: const [], failure: null);

  /// The rule the form describes, or null when the input isn't usable yet.
  BulkPriceRule? rule() {
    if (!state.hasScope) return null;
    final adjustment = _adjustment();
    if (adjustment == null) return null;
    return BulkPriceRule(
      categoryId: state.scope == BulkScope.category ? state.categoryId : null,
      includeSubcategories: state.includeSubcategories,
      productIds: state.scope == BulkScope.selection ? state.productIds : const [],
      adjustment: adjustment,
      target: state.target,
      rounding: state.target == PriceTarget.cost ? RoundingStep.none : state.rounding,
      roundingMode: state.roundingMode,
    );
  }

  PriceAdjustment? _adjustment() {
    final sign = state.increase ? 1 : -1;
    final text = normalizeDigits(state.amountText.trim()).replaceAll(',', '.');
    if (text.isEmpty) return null;
    if (state.mode == BulkMode.percent) {
      final value = double.tryParse(text);
      if (value == null || value <= 0 || !value.isFinite) return null;
      return PriceAdjustment.percent(value * sign);
    }
    final amount = Money.tryParse(text, _currency);
    if (amount == null || amount.isZero) return null;
    return PriceAdjustment.fixed(state.increase ? amount : -amount);
  }

  /// Loads the preview table for the current form.
  Future<void> loadPreview() async {
    final rule = this.rule();
    if (rule == null) {
      state = state.copyWith(formError: state.hasScope ? 'amount' : 'scope');
      return;
    }
    state = state.copyWith(busy: true, failure: null, formError: null);
    final result = await ref.read(previewBulkPricesProvider)(rule);
    state = switch (result) {
      Success<List<PriceChangePreview>>(:final value) =>
        state.copyWith(busy: false, preview: value, phase: BulkPhase.preview),
      Err<List<PriceChangePreview>>(:final failure) =>
        state.copyWith(busy: false, failure: failure),
    };
  }

  /// Applies the rule, then switches to the summary.
  Future<void> apply() async {
    final rule = this.rule();
    if (rule == null) return;
    state = state.copyWith(busy: true, failure: null);
    final duration = ref.read(clockProvider).now().difference(state.startedAt);
    final result = await ref.read(applyBulkPricesProvider)(rule, duration: duration);
    state = switch (result) {
      Success<PriceBatchResult>(:final value) =>
        state.copyWith(busy: false, result: value, phase: BulkPhase.done),
      Err<PriceBatchResult>(:final failure) => state.copyWith(busy: false, failure: failure),
    };
  }
}
