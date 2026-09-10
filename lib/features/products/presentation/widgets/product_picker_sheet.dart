import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';
import 'barcode_scan_action.dart';
import 'product_search_field.dart';
import 'product_tile.dart';

/// Search-or-scan chooser used by stock, pricing and the dashboard.
/// Returns the chosen product, or null if dismissed.
Future<Product?> showProductPickerSheet(BuildContext context) => showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _ProductPickerSheet(),
    );

class _ProductPickerSheet extends ConsumerStatefulWidget {
  const _ProductPickerSheet();

  @override
  ConsumerState<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends ConsumerState<_ProductPickerSheet> {
  /// Its own query, so it never disturbs the filters of the product list.
  ProductQuery _query = const ProductQuery(limit: 25);

  Future<void> _scan() async {
    final outcome = await scanAndFind(context, ref);
    if (!mounted) return;
    switch (outcome) {
      case ScanFound(:final product):
        Navigator.of(context).pop(product);
      case ScanUnknown(:final barcode):
        setState(() => _query = _query.copyWith(search: barcode));
      case ScanCancelled():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = ref.watch(productListProvider(_query));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.catalogue_pickerTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ProductSearchField(
                    autofocus: true,
                    hintText: l10n.catalogue_pickerSearchHint,
                    initialValue: _query.search,
                    onChanged: (value) =>
                        setState(() => _query = _query.copyWith(search: value)),
                    onSubmitted: (value) {
                      final items = ref.read(productListProvider(_query)).value ?? const [];
                      if (items.length == 1) Navigator.of(context).pop(items.first.product);
                    },
                    trailing: BarcodeScanAction(onPressed: _scan),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (results) {
                AsyncData(:final value) when value.isEmpty => Center(
                    child: Text(l10n.catalogue_pickerEmpty),
                  ),
                AsyncData(:final value) => ListView.separated(
                    itemCount: value.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) => ProductTile(
                      dense: true,
                      summary: value[index],
                      onTap: () => Navigator.of(context).pop(value[index].product),
                    ),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}
