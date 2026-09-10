import 'package:flutter/material.dart';

import '../domain/stock_status.dart';
import '../l10n/l10n.dart';
import '../theme/spacing.dart';
import '../theme/stock_colors.dart';

/// Pill showing ok / low / out with fixed semantic colours (AD-8).
class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key});
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final c = StockColors.of(context);
    final l10n = context.l10n;
    final (bg, fg, label, icon) = switch (status) {
      StockStatus.ok => (c.okContainer, c.ok, l10n.common_stockOk, Icons.check_circle_outline),
      StockStatus.low => (c.lowContainer, c.low, l10n.common_stockLow, Icons.warning_amber_rounded),
      StockStatus.out => (c.outContainer, c.out, l10n.common_stockOut, Icons.remove_circle_outline),
    };
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
        ],
      ),
    );
  }
}
