// OWNER: A4. Quick adjust: pick a product, say what happened, save.
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
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/stock_badge.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';
import '../../domain/usecases/record_stock_movement.dart';
import '../providers/stock_providers.dart';
import '../widgets/movement_labels.dart';
import '../widgets/product_code_field.dart';

class AdjustStockPage extends ConsumerStatefulWidget {
  const AdjustStockPage({super.key, this.productId});

  /// Set when the screen is opened from a product (see `StockRoutes.adjustFor`).
  final String? productId;

  @override
  ConsumerState<AdjustStockPage> createState() => _AdjustStockPageState();
}

class _AdjustStockPageState extends ConsumerState<AdjustStockPage> {
  final _quantity = TextEditingController(text: '1');
  final _note = TextEditingController();
  ProductStock? _picked;
  MovementType _type = MovementType.adjustment;
  bool _removes = false;
  bool _saving = false;
  String? _quantityError;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// Corrections carry their own sign; every other type has a fixed direction.
  int _signFor(MovementType type) => type.sign == 0 ? (_removes ? -1 : 1) : type.sign;

  Quantity? _parsed(ProductStock product) =>
      Quantity.tryParse(_quantity.text, unit: product.unit);

  Future<void> _save(ProductStock product) async {
    final l10n = context.l10n;
    final quantity = _parsed(product);
    if (quantity == null || quantity.isZero) {
      setState(() => _quantityError = product.unit.allowsDecimals
          ? l10n.stock_invalidQuantity
          : l10n.stock_invalidWholeQuantity);
      return;
    }
    setState(() => _quantityError = null);

    final signed = Quantity(_signFor(_type) * quantity.milli);
    final after = product.quantity + signed;
    if (after.isNegative) {
      if (_type != MovementType.adjustment) {
        _message(l10n.stock_negativeNotAllowed);
        return;
      }
      final confirmed = await showConfirmDialog(
        context,
        title: l10n.stock_negativeConfirmTitle,
        message: l10n.stock_negativeConfirmBody(after.toDecimalString()),
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _saving = true);
    final note = _note.text.trim();
    final result = await ref.read(recordStockMovementProvider)(
      MovementInput(
        productId: product.productId,
        type: _type,
        // Typed movements take a magnitude, corrections a signed value.
        quantity: _type.sign == 0 ? signed : quantity,
        note: note.isEmpty ? null : note,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.fold(
      (movement) {
        _message(l10n.stock_adjustDone(
          '${movement.quantityAfter.toDecimalString()} ${unitLabel(l10n, product.unit)}',
        ));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RoutePaths.stock);
        }
      },
      (failure) => _message(failureMessage(l10n, failure)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final id = widget.productId;
    final async = id == null ? null : ref.watch(productStockProvider(id));
    final product = _picked ?? async?.value;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.stock_adjustTitle)),
      body: switch (async) {
        AsyncError(:final error) => ErrorView(error: error),
        _ => ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (id == null) ...[
                ProductCodeField(
                  onProduct: (p) => setState(() => _picked = p),
                  hintText: l10n.stock_pickProduct,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (product == null)
                Text(
                  l10n.stock_pickProductBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              else
                _AdjustForm(
                  product: product,
                  type: _type,
                  removes: _removes,
                  saving: _saving,
                  quantityController: _quantity,
                  noteController: _note,
                  quantityError: _quantityError,
                  onTypeChanged: (t) => setState(() => _type = t),
                  onDirectionChanged: (removes) => setState(() => _removes = removes),
                  onQuantityChanged: () => setState(() {}),
                  preview: () {
                    final quantity = _parsed(product);
                    if (quantity == null) return null;
                    return product.quantity + Quantity(_signFor(_type) * quantity.milli);
                  },
                  onSave: () => _save(product),
                ),
            ],
          ),
      },
    );
  }
}

class _AdjustForm extends ConsumerWidget {
  const _AdjustForm({
    required this.product,
    required this.type,
    required this.removes,
    required this.saving,
    required this.quantityController,
    required this.noteController,
    required this.quantityError,
    required this.onTypeChanged,
    required this.onDirectionChanged,
    required this.onQuantityChanged,
    required this.preview,
    required this.onSave,
  });

  final ProductStock product;
  final MovementType type;
  final bool removes;
  final bool saving;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  final String? quantityError;
  final ValueChanged<MovementType> onTypeChanged;
  final ValueChanged<bool> onDirectionChanged;
  final VoidCallback onQuantityChanged;
  final Quantity? Function() preview;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final after = preview();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(product.name, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              l10n.stock_currentQuantity(
                '${formatters.quantity(product.quantity)} ${unitLabel(l10n, product.unit)}',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(width: AppSpacing.sm),
            StockBadge(product.status),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.stock_reasonLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final t in adjustableTypes)
              ChoiceChip(
                selected: type == t,
                onSelected: (_) => onTypeChanged(t),
                avatar: Icon(movementTypeIcon(t), size: 18),
                label: Text(movementTypeLabel(l10n, t)),
              ),
          ],
        ),
        if (type.sign == 0) ...[
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.add),
                label: Text(l10n.stock_directionAdd),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.remove),
                label: Text(l10n.stock_directionRemove),
              ),
            ],
            selected: {removes},
            onSelectionChanged: (s) => onDirectionChanged(s.first),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: quantityController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: l10n.stock_quantityLabel,
            suffixText: unitLabel(l10n, product.unit),
            errorText: quantityError,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => onQuantityChanged(), // keeps the preview in step
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: noteController,
          maxLength: RecordStockMovement.maxNoteLength,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.stock_noteLabel,
            helperText: l10n.stock_noteHelper,
            border: const OutlineInputBorder(),
          ),
        ),
        if (after != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Row(
              children: [
                Text(
                  l10n.stock_afterQuantity(
                    '${formatters.quantity(after)} ${unitLabel(l10n, product.unit)}',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(width: AppSpacing.sm),
                StockBadge(
                  RecordStockMovement.statusFor(after, product.reorderPoint),
                ),
              ],
            ),
          ),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(l10n.common_save),
        ),
      ],
    );
  }
}
