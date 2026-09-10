// OWNER: A4. Receive a delivery: scan → quantity → next, then one transaction.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/quantity.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/stock_view.dart';
import '../providers/receive_draft.dart';
import '../widgets/movement_labels.dart';
import '../widgets/product_code_field.dart';
import '../widgets/quantity_dialog.dart';

class ReceiveDeliveryPage extends ConsumerStatefulWidget {
  const ReceiveDeliveryPage({super.key});

  @override
  ConsumerState<ReceiveDeliveryPage> createState() => _ReceiveDeliveryPageState();
}

class _ReceiveDeliveryPageState extends ConsumerState<ReceiveDeliveryPage> {
  final _fieldKey = GlobalKey<ProductCodeFieldState>();
  bool _saving = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// One scan: ask how many arrived (and optionally what they cost), add the
  /// line, then put the cursor back in the field for the next barcode.
  Future<void> _addProduct(ProductStock product) async {
    final entry = await showQuantityDialog(
      context,
      product: product,
      askUnitCost: true,
    );
    _fieldKey.currentState?.focus();
    if (entry == null) return;
    ref.read(receiveDraftProvider.notifier).add(
          product,
          entry.quantity,
          unitCost: entry.unitCost,
        );
  }

  Future<void> _editLine(ReceiveLine line) async {
    final entry = await showQuantityDialog(
      context,
      product: line.product,
      initial: line.quantity,
      unitCost: line.unitCost,
      askUnitCost: true,
    );
    if (entry == null) return;
    ref.read(receiveDraftProvider.notifier)
      ..setQuantity(line.product.productId, entry.quantity)
      ..setUnitCost(line.product.productId, entry.unitCost);
  }

  Future<void> _finish() async {
    final l10n = context.l10n;
    final lines = ref.read(appFormattersProvider).number(ref.read(receiveDraftProvider).length);
    setState(() => _saving = true);
    final result = await ref.read(receiveDraftProvider.notifier).submit();
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (batch) {
        _message(l10n.stock_receiveDone(lines));
        context.go(RoutePaths.stock);
      },
      (failure) => _message(failureMessage(l10n, failure)),
    );
  }

  Future<void> _discard() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stock_discardTitle,
      message: l10n.stock_discardBody,
      confirmLabel: l10n.common_delete,
      destructive: true,
    );
    if (confirmed) ref.read(receiveDraftProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final lines = ref.watch(receiveDraftProvider);
    final total = lines.fold(const Quantity.zero(), (sum, line) => sum + line.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.stock_receiveTitle),
        actions: [
          if (lines.isNotEmpty)
            IconButton(
              onPressed: _saving ? null : _discard,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.stock_discardTitle,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ProductCodeField(key: _fieldKey, onProduct: _addProduct),
          ),
          Expanded(
            child: lines.isEmpty
                ? EmptyState(
                    icon: Icons.qr_code_scanner,
                    title: l10n.stock_receiveEmptyTitle,
                    message: l10n.stock_receiveEmptyBody,
                  )
                : ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[lines.length - 1 - index];
                      return ListTile(
                        title: Text(line.product.name),
                        subtitle: line.unitCost == null
                            ? null
                            : DefaultTextStyle.merge(
                                style: theme.textTheme.bodySmall,
                                child: MoneyText(line.unitCost!),
                              ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${formatters.quantity(line.quantity)} '
                              '${unitLabel(l10n, line.product.unit)}',
                              style: theme.textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed: () => ref
                                  .read(receiveDraftProvider.notifier)
                                  .remove(line.product.productId),
                              icon: const Icon(Icons.close),
                              tooltip: l10n.common_delete,
                            ),
                          ],
                        ),
                        onTap: () => _editLine(line),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.stock_receiveSummary(
                    formatters.number(lines.length),
                    formatters.quantity(total),
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              FilledButton.icon(
                onPressed: lines.isEmpty || _saving ? null : _finish,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(l10n.stock_finish),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
