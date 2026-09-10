// OWNER: A4. Public surface of the stock feature (AGENT_PHASES §6).
// W0 stubs — A4 replaces the bodies, keeping names and signatures.
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/l10n/l10n.dart';

part 'public.g.dart';

/// Number of open low/out alerts at the current branch (nav badge).
@riverpod
Stream<int> openAlertCount(Ref ref) => Stream.value(0);

/// Movement timeline for the product detail screen (used by A2).
class StockHistorySection extends StatelessWidget {
  const StockHistorySection({super.key, required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.history),
        title: Text(context.l10n.stock_historyTitle),
        subtitle: Text(context.l10n.common_comingSoonTitle),
      );
}
