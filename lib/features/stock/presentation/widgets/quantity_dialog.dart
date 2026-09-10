// OWNER: A4. Quantity (and optional unit cost) for one line of a delivery.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock_view.dart';
import 'movement_labels.dart';

class QuantityEntry {
  const QuantityEntry(this.quantity, this.unitCost);
  final Quantity quantity;
  final Money? unitCost;
}

Future<QuantityEntry?> showQuantityDialog(
  BuildContext context, {
  required ProductStock product,
  Quantity initial = const Quantity.whole(1),
  Money? unitCost,
  bool askUnitCost = false,
  bool allowNegative = false,
}) =>
    showDialog<QuantityEntry>(
      context: context,
      builder: (_) => _QuantityDialog(
        product: product,
        initial: initial,
        unitCost: unitCost,
        askUnitCost: askUnitCost,
        allowNegative: allowNegative,
      ),
    );

class _QuantityDialog extends ConsumerStatefulWidget {
  const _QuantityDialog({
    required this.product,
    required this.initial,
    required this.unitCost,
    required this.askUnitCost,
    required this.allowNegative,
  });

  final ProductStock product;
  final Quantity initial;
  final Money? unitCost;
  final bool askUnitCost;
  final bool allowNegative;

  @override
  ConsumerState<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends ConsumerState<_QuantityDialog> {
  late final TextEditingController _quantity =
      TextEditingController(text: widget.initial.toDecimalString());
  late final TextEditingController _cost =
      TextEditingController(text: widget.unitCost?.toDecimalString() ?? '');
  String? _quantityError;
  String? _costError;

  @override
  void dispose() {
    _quantity.dispose();
    _cost.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final currency = ref.read(sessionControllerProvider).store?.currency ?? 'EGP';
    final quantity = Quantity.tryParse(
      _quantity.text,
      unit: widget.product.unit,
      allowNegative: widget.allowNegative,
    );
    Money? cost;
    if (widget.askUnitCost && _cost.text.trim().isNotEmpty) {
      cost = Money.tryParse(_cost.text, currency);
      if (cost == null) {
        setState(() => _costError = l10n.stock_invalidAmount);
        return;
      }
    }
    if (quantity == null || quantity.isZero) {
      setState(() => _quantityError = widget.product.unit.allowsDecimals
          ? l10n.stock_invalidQuantity
          : l10n.stock_invalidWholeQuantity);
      return;
    }
    Navigator.of(context).pop(QuantityEntry(quantity, cost));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _quantity,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.stock_quantityLabel,
              suffixText: unitLabel(l10n, widget.product.unit),
              errorText: _quantityError,
              border: const OutlineInputBorder(),
            ),
          ),
          if (widget.askUnitCost) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.stock_unitCostLabel,
                helperText: l10n.stock_unitCostHelper,
                errorText: _costError,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.common_ok)),
      ],
    );
  }
}
