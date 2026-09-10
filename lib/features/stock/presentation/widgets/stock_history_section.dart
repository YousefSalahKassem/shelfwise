// OWNER: A4. Stock block of the product detail screen (A2 embeds it through
// stock/public.dart): current level, reorder point and the movement timeline.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/stock_badge.dart';
import '../../domain/entities/stock_view.dart';
import '../providers/stock_providers.dart';
import '../routes.dart';
import 'movement_labels.dart';
import 'movement_tile.dart';
import 'reorder_point_dialog.dart';

class StockHistoryView extends ConsumerWidget {
  const StockHistoryView({super.key, required this.productId, this.maxMovements = 10});

  final String productId;
  final int maxMovements;

  Future<void> _editReorderPoint(
    BuildContext context,
    WidgetRef ref,
    ProductStock product,
  ) async {
    final value = await showReorderPointDialog(
      context,
      productName: product.name,
      unit: product.unit,
      initial: product.reorderPoint,
    );
    if (value == null || !context.mounted) return;
    final result = await ref.read(setReorderPointProvider)(product.productId, value);
    if (!context.mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.fold(
              (_) => l10n.stock_reorderPointSaved,
              (failure) => failureMessage(l10n, failure),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final stock = ref.watch(productStockProvider(productId));
    final movements = ref.watch(productMovementsProvider(productId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
          child: Text(l10n.stock_historyTitle, style: theme.textTheme.titleMedium),
        ),
        switch (stock) {
          AsyncData(:final value) => _Summary(
              product: value,
              canSetReorderPoint: session.can(Permission.setReorderPoints),
              canAdjust: session.can(Permission.adjustStock),
              onEditReorderPoint: () => _editReorderPoint(context, ref, value),
            ),
          AsyncError(:final error) => ErrorView(error: error),
          _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LinearProgressIndicator(),
            ),
        },
        const Divider(height: AppSpacing.xl),
        switch (movements) {
          AsyncData(:final value) when value.isEmpty => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.stock_noMovements,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          AsyncData(:final value) => Column(
              children: [
                for (final entry in value.take(maxMovements))
                  MovementTile(entry: entry, showProductName: false),
              ],
            ),
          AsyncError(:final error) => ErrorView(error: error),
          _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LinearProgressIndicator(),
            ),
        },
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.product,
    required this.canSetReorderPoint,
    required this.canAdjust,
    required this.onEditReorderPoint,
  });

  final ProductStock product;
  final bool canSetReorderPoint;
  final bool canAdjust;
  final VoidCallback onEditReorderPoint;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              QuantityText(
                product.quantity,
                unitLabel: unitLabel(l10n, product.unit),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(width: AppSpacing.md),
              StockBadge(product.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.stock_reorderPointValue(
                    '${product.reorderPoint.toDecimalString()} ${unitLabel(l10n, product.unit)}',
                  ),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (canSetReorderPoint)
                TextButton.icon(
                  onPressed: onEditReorderPoint,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.common_edit),
                ),
            ],
          ),
          if (canAdjust) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.go(StockRoutes.adjustFor(product.productId)),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(l10n.stock_adjustTitle),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go(RoutePaths.stockReceive),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: Text(l10n.stock_receiveTitle),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
