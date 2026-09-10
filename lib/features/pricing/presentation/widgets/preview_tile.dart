import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/pricing.dart';

/// One row of the preview table: old → new price, margin, and the below-cost /
/// zero flags. Direction-safe: the arrow follows the text direction.
class PreviewTile extends ConsumerWidget {
  const PreviewTile({super.key, required this.preview});

  final PriceChangePreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final unchanged = preview.newPrice == preview.oldPrice && preview.newCost == preview.oldCost;
    final margin = Money.marginPercent(price: preview.newPrice, cost: preview.newCost);
    const tabular = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.productName,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${l10n.pricing_margin} '
                  '${margin == null ? l10n.pricing_marginNone : formatters.percent(margin)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: preview.belowCost
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatters.money(preview.oldPrice, withSymbol: false),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: unchanged ? null : TextDecoration.lineThrough,
                        )
                        .merge(tabular),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.arrow_forward, size: 14),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    formatters.money(preview.newPrice),
                    style: theme.textTheme.titleSmall?.merge(tabular),
                  ),
                ],
              ),
              if (preview.belowCost || preview.isZero) ...[
                const SizedBox(height: AppSpacing.xxs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    if (preview.isZero) _Flag(label: l10n.pricing_flagZero),
                    if (preview.belowCost) _Flag(label: l10n.pricing_flagBelowCost),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onErrorContainer),
      ),
    );
  }
}
