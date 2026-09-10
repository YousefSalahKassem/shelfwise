import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/entities/product.dart';
import '../providers/product_filter_controller.dart';
import '../providers/product_providers.dart';
import '../widgets/barcode_scan_action.dart';
import '../widgets/product_filter_bar.dart';
import '../widgets/product_search_field.dart';
import '../widgets/product_tile.dart';

/// Search, filter and browse the catalogue. Reacts to `dbChanges`, so a stock
/// movement or a price change updates the rows without a refresh.
class ProductListPage extends ConsumerStatefulWidget {
  const ProductListPage({super.key});

  @override
  ConsumerState<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends ConsumerState<ProductListPage> {
  final _scrollController = ScrollController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Infinite scroll: ask for one more page shortly before the end.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      final query = ref.read(productFilterControllerProvider);
      final loaded = ref.read(productListProvider(query)).value?.length ?? 0;
      final total = ref.read(productMatchCountProvider(query)).value ?? 0;
      if (loaded >= query.limit && loaded < total) {
        ref.read(productFilterControllerProvider.notifier).loadMore();
      }
    }
  }

  Future<void> _scan() async {
    final outcome = await scanAndFind(context, ref);
    if (!mounted) return;
    switch (outcome) {
      case ScanFound(:final product):
        context.go(RoutePaths.productDetailFor(product.id));
      case ScanUnknown(:final barcode):
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(context.l10n.catalogue_scanNotFound(barcode)),
              action: SnackBarAction(
                label: context.l10n.catalogue_addProduct,
                onPressed: () => context.go('${RoutePaths.productNew}?barcode=$barcode'),
              ),
            ),
          );
      case ScanCancelled():
        break;
    }
  }

  /// A scanner typing into the search box ends with Enter: if exactly one
  /// product matches, open it straight away.
  Future<void> _onSubmitted(String value) async {
    if (value.isEmpty) return;
    final result = await ref.read(findProductByBarcodeProvider)(value);
    final product = result.valueOrNull;
    if (product != null && mounted) {
      context.go(RoutePaths.productDetailFor(product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = ref.watch(productFilterControllerProvider);
    final controller = ref.read(productFilterControllerProvider.notifier);
    final products = ref.watch(productListProvider(query));
    final total = ref.watch(productMatchCountProvider(query)).value;
    final canEdit = ref.watch(sessionControllerProvider).can(Permission.editCatalogue);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.catalogue_productsTitle),
        actions: [
          IconButton(
            tooltip: l10n.catalogue_categoriesTitle,
            icon: const Icon(Icons.category_outlined),
            onPressed: () => context.go(RoutePaths.categories),
          ),
          BarcodeScanAction(onPressed: _scan),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_showFilters ? 190 : 64),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: ProductSearchField(
                  initialValue: query.search,
                  onChanged: controller.setSearch,
                  onSubmitted: _onSubmitted,
                  trailing: IconButton(
                    tooltip: l10n.catalogue_filterStatus,
                    isSelected: _showFilters,
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                ),
              ),
              if (_showFilters) const ProductFilterBar(),
              if (_showFilters) const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => context.go(RoutePaths.productNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.catalogue_addProduct),
            )
          : null,
      body: switch (products) {
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(productListProvider(query)),
          ),
        AsyncData(:final value) when value.isEmpty => _EmptyList(
            filtered: controller.hasFilters,
            canEdit: canEdit,
            onClear: controller.clear,
          ),
        AsyncData(:final value) => _ProductListView(
            summaries: value,
            total: total ?? value.length,
            scrollController: _scrollController,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProductListView extends StatelessWidget {
  const _ProductListView({
    required this.summaries,
    required this.total,
    required this.scrollController,
  });

  final List<ProductSummary> summaries;
  final int total;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasMore = summaries.length < total;
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
      itemCount: summaries.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == summaries.length) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: hasMore
                  ? const CircularProgressIndicator()
                  : Text(
                      l10n.catalogue_resultCount(total),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          );
        }
        final summary = summaries[index];
        return ProductTile(
          summary: summary,
          onTap: () => context.go(RoutePaths.productDetailFor(summary.product.id)),
        );
      },
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.filtered,
    required this.canEdit,
    required this.onClear,
  });

  final bool filtered;
  final bool canEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (filtered) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.catalogue_noResultsTitle,
        message: l10n.catalogue_noResultsBody,
        action: OutlinedButton(
          onPressed: onClear,
          child: Text(l10n.catalogue_clearFilters),
        ),
      );
    }
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: l10n.catalogue_emptyTitle,
      message: l10n.catalogue_emptyBody,
      action: canEdit
          ? FilledButton.icon(
              onPressed: () => context.go(RoutePaths.productNew),
              icon: const Icon(Icons.add),
              label: Text(l10n.catalogue_addProduct),
            )
          : null,
    );
  }
}
