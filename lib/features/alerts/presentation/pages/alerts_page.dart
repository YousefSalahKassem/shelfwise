// OWNER: A4. What is out of stock, what is about to be, and one tap to fix it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/entities/stock_alert.dart';
import '../providers/alert_providers.dart';
import '../widgets/alert_tile.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  Future<void> _acknowledge(BuildContext context, WidgetRef ref, StockAlert alert) async {
    final result = await ref.read(acknowledgeAlertProvider)(alert);
    if (!context.mounted) return;
    final l10n = context.l10n;
    result.fold(
      (_) {},
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure)))),
    );
  }

  Future<void> _receive(BuildContext context, WidgetRef ref, StockAlert alert) async {
    await ref.read(alertOpenedLoggerProvider)(alert, action: 'receive');
    if (context.mounted) context.go(RoutePaths.stockReceive);
  }

  Future<void> _openProduct(BuildContext context, WidgetRef ref, StockAlert alert) async {
    await ref.read(alertOpenedLoggerProvider)(alert, action: 'product');
    if (context.mounted) context.go(RoutePaths.productDetailFor(alert.productId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final alerts = ref.watch(openAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.alerts_title)),
      body: switch (alerts) {
        AsyncData(:final value) when value.isEmpty => EmptyState(
            icon: Icons.check_circle_outline,
            title: l10n.alerts_emptyTitle,
            message: l10n.alerts_emptyBody,
          ),
        AsyncData(:final value) => _AlertList(
            alerts: value,
            onReceive: (alert) => _receive(context, ref, alert),
            onAcknowledge: (alert) => _acknowledge(context, ref, alert),
            onOpenProduct: (alert) => _openProduct(context, ref, alert),
          ),
        AsyncError(:final error) => ErrorView(error: error),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _AlertList extends ConsumerWidget {
  const _AlertList({
    required this.alerts,
    required this.onReceive,
    required this.onAcknowledge,
    required this.onOpenProduct,
  });

  final List<StockAlert> alerts;
  final ValueChanged<StockAlert> onReceive;
  final ValueChanged<StockAlert> onAcknowledge;
  final ValueChanged<StockAlert> onOpenProduct;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final formatters = ref.watch(appFormattersProvider);
    final out = [for (final a in alerts) if (a.level == StockStatus.out) a];
    final low = [for (final a in alerts) if (a.level != StockStatus.out) a];

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (out.isNotEmpty) ...[
          _SectionHeader(label: l10n.alerts_sectionOut(formatters.number(out.length))),
          for (final alert in out) _tile(alert),
        ],
        if (low.isNotEmpty) ...[
          _SectionHeader(label: l10n.alerts_sectionLow(formatters.number(low.length))),
          for (final alert in low) _tile(alert),
        ],
      ],
    );
  }

  Widget _tile(StockAlert alert) => AlertTile(
        key: ValueKey(alert.id),
        alert: alert,
        onReceive: () => onReceive(alert),
        onAcknowledge: () => onAcknowledge(alert),
        onOpenProduct: () => onOpenProduct(alert),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xs),
        child: Text(label, style: Theme.of(context).textTheme.titleSmall),
      );
}
