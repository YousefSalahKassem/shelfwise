// OWNER: A4. The lines of a delivery being received, before they are committed.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/error/result.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';
import 'stock_providers.dart';

part 'receive_draft.g.dart';

@immutable
class ReceiveLine {
  const ReceiveLine({required this.product, required this.quantity, this.unitCost});

  final ProductStock product;
  final Quantity quantity;
  final Money? unitCost;

  ReceiveLine copyWith({Quantity? quantity, Money? unitCost}) => ReceiveLine(
        product: product,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
      );
}

/// Scan → quantity → next. Lines are kept until "finish" commits them all in
/// one transaction, so a delivery is one ledger entry per product, not per scan.
@riverpod
class ReceiveDraft extends _$ReceiveDraft {
  @override
  List<ReceiveLine> build() => const [];

  /// Scanning the same product twice adds up instead of creating two lines.
  void add(ProductStock product, Quantity quantity, {Money? unitCost}) {
    final index = state.indexWhere((l) => l.product.productId == product.productId);
    if (index < 0) {
      state = [...state, ReceiveLine(product: product, quantity: quantity, unitCost: unitCost)];
      return;
    }
    final line = state[index];
    state = [...state]..[index] = line.copyWith(
        quantity: line.quantity + quantity,
        unitCost: unitCost ?? line.unitCost,
      );
  }

  void setQuantity(String productId, Quantity quantity) {
    state = [
      for (final line in state)
        line.product.productId == productId ? line.copyWith(quantity: quantity) : line,
    ];
  }

  void setUnitCost(String productId, Money? unitCost) {
    state = [
      for (final line in state)
        if (line.product.productId == productId)
          ReceiveLine(product: line.product, quantity: line.quantity, unitCost: unitCost)
        else
          line,
    ];
  }

  void remove(String productId) =>
      state = [for (final line in state) if (line.product.productId != productId) line];

  void clear() => state = const [];

  Quantity get totalQuantity =>
      state.fold(const Quantity.zero(), (sum, line) => sum + line.quantity);

  /// Commits every line in one transaction and empties the draft on success.
  Future<Result<MovementBatch>> submit() async {
    final lines = state;
    final result = await ref.read(recordStockMovementProvider).many([
      for (final line in lines)
        MovementInput(
          productId: line.product.productId,
          type: MovementType.receive,
          quantity: line.quantity,
          unitCost: line.unitCost,
        ),
    ]);
    if (result.isSuccess) state = const [];
    return result;
  }
}
