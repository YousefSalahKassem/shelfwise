// OWNER: A4. Stock home: what needs attention, the two write actions, and
// what the store has done lately.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/stock_colors.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../alerts/presentation/providers/alert_providers.dart';
import '../providers/stock_providers.dart';
import '../widgets/movement_tile.dart';

class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionControllerProvider);
    final counts = ref.watch(alertCountsProvider).value;
    final movements = ref.watch(recentMovementsProvider());
    final canReceive = session.can(Permission.recordStock);
    final canAdjust = session.can(Permission.adjustStock);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stock_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        children: [
          if (counts != null && counts.total > 0)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: _AlertSummaryCard(low: counts.low, out: counts.out),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                if (canReceive)
                  FilledButton.icon(
                    onPressed: () => context.go(RoutePaths.stockReceive),
                    icon: const Icon(Icons.arrow_downward),
                    label: Text(l10n.stock_receiveTitle),
                  ),
                if (canAdjust)
                  OutlinedButton.icon(
                    onPressed: () => context.go(RoutePaths.stockAdjust),
                    icon: const Icon(Icons.tune),
                    label: Text(l10n.stock_adjustTitle),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Text(
              l10n.stock_recentTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          switch (movements) {
            AsyncData(:final value) when value.isEmpty => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: EmptyState(
                icon: Icons.move_to_inbox_outlined,
                title: l10n.stock_noMovements,
                message: l10n.stock_noMovementsBody,
                action: canReceive
                    ? FilledButton(
                        onPressed: () => context.go(RoutePaths.stockReceive),
                        child: Text(l10n.stock_receiveTitle),
                      )
                    : null,
              ),
            ),
            AsyncData(:final value) => Column(
              children: [for (final entry in value) MovementTile(entry: entry)],
            ),
            AsyncError(:final error) => ErrorView(error: error),
            _ => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LinearProgressIndicator(),
            ),
          },
        ],
      ),
    );
  }
}

class _AlertSummaryCard extends ConsumerWidget {
  const _AlertSummaryCard({required this.low, required this.out});

  final int low;
  final int out;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = StockColors.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final critical = out > 0;
    return Card.filled(
      color: critical ? colors.outContainer : colors.lowContainer,
      child: ListTile(
        leading: Icon(
          critical ? Icons.remove_circle_outline : Icons.warning_amber_rounded,
          color: critical ? colors.out : colors.low,
        ),
        title: Text(
          l10n.stock_alertSummary(
            formatters.number(out),
            formatters.number(low),
          ),
          style: TextStyle(color: critical ? colors.out : colors.low),
        ),
        // Chevrons don't mirror themselves; pick the one the direction needs.
        trailing: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.chevron_left
              : Icons.chevron_right,
        ),
        onTap: () => context.go(RoutePaths.alerts),
      ),
    );
  }
}
