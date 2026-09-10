import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/stock_badge.dart';
import '../../../stock/public.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import '../util/unit_label.dart';
import '../widgets/product_tile.dart';

/// Everything about one product: info, price and margin, current stock
/// (read-only — A4 owns movements) and its stock history.
class ProductDetailPage extends ConsumerWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(productSummaryProvider(productId));
    final canEdit = ref
        .watch(sessionControllerProvider)
        .can(Permission.editCatalogue);

    return Scaffold(
      appBar: AppBar(
        title: Text(summary.value?.product.name ?? l10n.catalogue_productTitle),
        actions: [
          if (canEdit && summary.value != null) ...[
            IconButton(
              tooltip: l10n.common_edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.go(RoutePaths.productEditFor(productId)),
            ),
            _ArchiveButton(product: summary.value!.product),
          ],
        ],
      ),
      body: switch (summary) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(productSummaryProvider(productId)),
        ),
        AsyncData(value: null) => EmptyState(
          icon: Icons.search_off,
          title: l10n.common_errorNotFound,
          action: OutlinedButton(
            onPressed: () => context.go(RoutePaths.products),
            child: Text(l10n.catalogue_productsTitle),
          ),
        ),
        AsyncData(:final value?) => _ProductDetailView(summary: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProductDetailView extends ConsumerWidget {
  const _ProductDetailView({required this.summary});

  final ProductSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final product = summary.product;
    final formatters = ref.watch(appFormattersProvider);
    final canEditPrices = ref
        .watch(sessionControllerProvider)
        .can(Permission.editPrices);
    final margin = Money.marginPercent(
      price: product.price,
      cost: product.cost,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (product.isArchived)
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.catalogue_archivedNotice),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProductThumbnail(product: product, size: 88),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleLarge),
                  if (product.nameAlt != null)
                    Text(product.nameAlt!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.sm),
                  StockBadge(summary.status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // Price & margin
        Text(l10n.catalogue_priceSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                title: Text(l10n.catalogue_fieldPrice),
                trailing: MoneyText(
                  product.price,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              ListTile(
                title: Text(l10n.catalogue_fieldCost),
                trailing: MoneyText(product.cost),
              ),
              ListTile(
                title: Text(
                  margin == null
                      ? l10n.catalogue_margin(l10n.catalogue_marginUnknown)
                      : l10n.catalogue_margin(formatters.percent(margin)),
                ),
                subtitle: product.price < product.cost
                    ? Text(l10n.catalogue_belowCost)
                    : null,
                trailing: canEditPrices
                    ? TextButton(
                        onPressed: () =>
                            context.go(RoutePaths.priceEditFor(product.id)),
                        child: Text(l10n.catalogue_changePrice),
                      )
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Stock (read-only here; A4 owns the movements)
        Text(l10n.catalogue_currentStock, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.inventory_outlined),
                title: QuantityText(
                  summary.quantity,
                  unitLabel: unitLabel(context, product.unit),
                  style: theme.textTheme.titleMedium,
                ),
                trailing: StockBadge(summary.status),
              ),
              StockHistorySection(productId: product.id),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Details
        Text(l10n.catalogue_detailsSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              _DetailRow(
                label: l10n.catalogue_fieldCategory,
                value: summary.categoryName ?? l10n.catalogue_categoryNone,
              ),
              _DetailRow(
                label: l10n.catalogue_fieldSku,
                value: product.sku ?? '—',
              ),
              _DetailRow(
                label: l10n.catalogue_fieldBarcode,
                value: product.barcode ?? '—',
              ),
              _DetailRow(
                label: l10n.catalogue_fieldUnit,
                value: unitLabel(context, product.unit),
              ),
              _DetailRow(
                label: l10n.catalogue_lastUpdated(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(product.updatedAt.toLocal()),
                ),
                value: '',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    trailing: value.isEmpty
        ? null
        : Text(value, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _ArchiveButton extends ConsumerWidget {
  const _ArchiveButton({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return IconButton(
      tooltip: product.isArchived
          ? l10n.catalogue_unarchive
          : l10n.catalogue_archive,
      icon: Icon(
        product.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
      ),
      onPressed: () async {
        if (!product.isArchived) {
          final confirmed = await showConfirmDialog(
            context,
            title: l10n.catalogue_archiveTitle(product.name),
            message: l10n.catalogue_archiveBody,
            confirmLabel: l10n.catalogue_archive,
            destructive: true,
          );
          if (!confirmed || !context.mounted) return;
        }
        final result = await ref.read(archiveProductProvider)(
          product.id,
          archived: !product.isArchived,
        );
        if (!context.mounted) return;
        final failure = result.failureOrNull;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(
                failure != null
                    ? failureMessage(l10n, failure)
                    : product.isArchived
                    ? l10n.catalogue_saved
                    : l10n.catalogue_archived,
              ),
            ),
          );
      },
    );
  }
}
