// OWNER: A4. One row of the ledger: what changed, who did it and when.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/settings/preferences_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/stock_colors.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/stock_view.dart';
import 'movement_labels.dart';

class MovementTile extends ConsumerWidget {
  const MovementTile({super.key, required this.entry, this.showProductName = true});

  final MovementEntry entry;
  final bool showProductName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = StockColors.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final movement = entry.movement;
    final adds = !movement.delta.isNegative;
    final sign = adds ? '+' : '−';
    final magnitude = adds ? movement.delta : -movement.delta;
    final subtitle = <String>[
      movementTypeLabel(l10n, movement.type),
      if (movement.profileName != null && movement.profileName!.isNotEmpty)
        movement.profileName!,
      formatTimestamp(
        movement.createdAt,
        localeCode: Localizations.localeOf(context).languageCode,
        latinDigits: ref.watch(preferencesControllerProvider).latinDigits,
      ),
    ].join(' · ');

    return ListTile(
      contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      leading: CircleAvatar(
        backgroundColor: adds ? colors.okContainer : colors.outContainer,
        foregroundColor: adds ? colors.ok : colors.out,
        child: Icon(movementTypeIcon(movement.type), size: 20),
      ),
      title: Text(
        showProductName ? entry.productName : movementTypeLabel(l10n, movement.type),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (movement.note != null && movement.note!.isNotEmpty)
            Text(
              movement.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatters.quantity(magnitude)}',
            style: theme.textTheme.titleMedium?.copyWith(color: adds ? colors.ok : colors.out),
          ),
          Text(
            l10n.stock_afterQuantity(
              '${formatters.quantity(movement.quantityAfter)} ${unitLabel(l10n, entry.unit)}',
            ),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (movement.unitCost != null)
            MoneyText(movement.unitCost!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
