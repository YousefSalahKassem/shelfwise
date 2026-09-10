// OWNER: A4. Public surface of the stock feature (AGENT_PHASES §6).
// Everything else in `features/stock/` is private to A4; other features import
// this file or `domain/`.
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../alerts/presentation/providers/alert_providers.dart';
import 'presentation/widgets/stock_history_section.dart';

export 'domain/entities/stock.dart'
    show MovementInput, MovementType, StockLevel, StockMovement;
export 'domain/entities/stock_view.dart' show MovementEntry, ProductStock;

part 'public.g.dart';

/// Number of open low/out alerts at the current branch (nav badge).
@riverpod
Stream<int> openAlertCount(Ref ref) =>
    ref.watch(watchAlertsProvider).counts().map((counts) => counts.total);

/// Movement timeline for the product detail screen (used by A2): current level,
/// reorder point and who changed what, when and why.
class StockHistorySection extends StatelessWidget {
  const StockHistorySection({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) => StockHistoryView(productId: productId);
}
