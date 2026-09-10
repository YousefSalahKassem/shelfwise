import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/stock_status.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import '../../../categories/public.dart';
import '../../domain/entities/product.dart';
import '../providers/product_filter_controller.dart';

/// Category, stock status, archived and sort controls for the product list.
class ProductFilterBar extends ConsumerWidget {
  const ProductFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = ref.watch(productFilterControllerProvider);
    final controller = ref.read(productFilterControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: CategoryField(
            value: query.categoryId,
            label: l10n.catalogue_filterCategory,
            noneLabel: l10n.catalogue_categoryAll,
            onChanged: controller.setCategory,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              for (final status in StockStatus.values) ...[
                FilterChip(
                  label: Text(_statusLabel(context, status)),
                  selected: query.statuses.contains(status),
                  onSelected: (_) => controller.toggleStatus(status),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              FilterChip(
                label: Text(l10n.catalogue_showArchived),
                selected: query.includeArchived,
                onSelected: (value) => controller.setIncludeArchived(value: value),
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<ProductSort>(
                initialValue: query.sort,
                onSelected: controller.setSort,
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ProductSort.name,
                    child: Text(l10n.catalogue_sortName),
                  ),
                  PopupMenuItem(
                    value: ProductSort.recentlyUpdated,
                    child: Text(l10n.catalogue_sortRecent),
                  ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(switch (query.sort) {
                    ProductSort.name => l10n.catalogue_sortName,
                    ProductSort.recentlyUpdated => l10n.catalogue_sortRecent,
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _statusLabel(BuildContext context, StockStatus status) => switch (status) {
        StockStatus.ok => context.l10n.common_stockOk,
        StockStatus.low => context.l10n.common_stockLow,
        StockStatus.out => context.l10n.common_stockOut,
      };
}
