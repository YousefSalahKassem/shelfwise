// OWNER: A4. One open alert: what is short, how short, and what to do next.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/stock_colors.dart';
import '../../../../core/widgets/stock_badge.dart';
import '../../domain/entities/stock_alert.dart';

class AlertTile extends ConsumerWidget {
  const AlertTile({
    super.key,
    required this.alert,
    required this.onReceive,
    required this.onAcknowledge,
    this.onOpenProduct,
  });

  final StockAlert alert;
  final VoidCallback onReceive;
  final VoidCallback onAcknowledge;
  final VoidCallback? onOpenProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = StockColors.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final isOut = alert.level == StockStatus.out;
    final seen = alert.acknowledgedAt != null;

    return Card(
      margin: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      color: seen ? theme.colorScheme.surfaceContainerLow : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    alert.productName,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                StockBadge(alert.level),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.alerts_quantityLine(
                formatters.quantity(alert.quantity),
                formatters.quantity(alert.reorderPoint),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isOut ? colors.out : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                FilledButton.tonalIcon(
                  onPressed: onReceive,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: Text(l10n.alerts_receiveStock),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (onOpenProduct != null)
                  TextButton(
                    onPressed: onOpenProduct,
                    child: Text(l10n.alerts_openProduct),
                  ),
                const Spacer(),
                if (seen)
                  Tooltip(
                    message: l10n.alerts_acknowledged,
                    child: Icon(Icons.done_all, color: theme.colorScheme.outline),
                  )
                else
                  IconButton(
                    onPressed: onAcknowledge,
                    icon: const Icon(Icons.check),
                    tooltip: l10n.alerts_acknowledge,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
