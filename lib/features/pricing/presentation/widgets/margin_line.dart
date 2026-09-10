import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';

/// Live margin `(price − cost) / price` plus the below-cost / zero warnings.
class MarginLine extends ConsumerWidget {
  const MarginLine({super.key, required this.price, required this.cost});

  final Money price;
  final Money cost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final margin = Money.marginPercent(price: price, cost: cost);
    final belowCost = price < cost;
    final zero = price.isZero;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.pricing_margin, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.sm),
            Text(
              margin == null ? l10n.pricing_marginNone : formatters.percent(margin),
              style: theme.textTheme.titleMedium?.copyWith(
                color: belowCost ? theme.colorScheme.error : null,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        if (zero || belowCost) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_outlined, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  zero ? l10n.pricing_zeroPrice : l10n.pricing_belowCost,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
