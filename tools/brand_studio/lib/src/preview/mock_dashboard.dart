import 'package:flutter/material.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/l10n/l10n.dart';
import 'package:shelfwise/core/theme/spacing.dart';
import 'package:shelfwise/core/theme/stock_colors.dart';
import 'package:shelfwise/core/utils/formatters.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/core/utils/quantity.dart';

import '../brand_draft.dart';
import 'mock_data.dart';
import 'preview_frame.dart';

/// The home screen as the store owner will see it, with the brand's logo,
/// colours, language and currency.
class MockDashboard extends StatelessWidget {
  const MockDashboard({super.key, required this.draft});

  final BrandDraft draft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stock = StockColors.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final strings = MockStrings(language);
    final l10n = context.l10n;
    final formatters = AppFormatters(
      languageCode: language,
      latinDigits: draft.latinDigitsByDefault,
    );
    final attention = mockProducts.where((p) => p.status != StockStatus.ok).take(3).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
          child: DraftLogo(draft: draft, size: 28, dark: theme.brightness == Brightness.dark),
        ),
        title: Text(draft.appName.isEmpty ? 'ShelfWise' : draft.appName),
        actions: [
          Badge.count(
            count: 2,
            child: const Icon(Icons.notifications_outlined),
          ),
          const SizedBox(width: AppSpacing.lg),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(strings.dashboardTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  value: formatters.number(128),
                  label: strings.kpiProducts,
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurface,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Kpi(
                  value: formatters.money(Money(4250000, draft.defaultCurrency)),
                  label: strings.kpiValue,
                  background: scheme.primaryContainer,
                  foreground: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  value: formatters.number(6),
                  label: strings.kpiLow,
                  background: stock.lowContainer,
                  foreground: stock.low,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Kpi(
                  value: formatters.number(2),
                  label: strings.kpiOut,
                  background: stock.outContainer,
                  foreground: stock.out,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text(strings.needsAttention, style: theme.textTheme.titleMedium)),
              Text(
                strings.viewAll,
                style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            color: scheme.surfaceContainerLow,
            child: Column(
              children: [
                for (final product in attention)
                  ListTile(
                    dense: true,
                    title: Text(product.name(language), maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${strings.inStock}: ${formatters.quantity(Quantity(product.qtyMilli))}',
                    ),
                    trailing: StatusPill(status: product.status),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_box_outlined),
            label: Text(strings.receiveStock),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.common_navDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            label: l10n.common_navProducts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.swap_vert),
            label: l10n.common_navStock,
          ),
          NavigationDestination(
            icon: const Icon(Icons.warning_amber_rounded),
            label: l10n.common_navAlerts,
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String value;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(color: foreground),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
