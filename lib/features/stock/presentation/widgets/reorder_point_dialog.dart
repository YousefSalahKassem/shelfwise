// OWNER: A4. Sets the level at which a product starts warning the owner.
import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/utils/quantity.dart';
import 'movement_labels.dart';

Future<Quantity?> showReorderPointDialog(
  BuildContext context, {
  required String productName,
  required ProductUnit unit,
  required Quantity initial,
}) =>
    showDialog<Quantity>(
      context: context,
      builder: (_) =>
          _ReorderPointDialog(productName: productName, unit: unit, initial: initial),
    );

class _ReorderPointDialog extends StatefulWidget {
  const _ReorderPointDialog({
    required this.productName,
    required this.unit,
    required this.initial,
  });

  final String productName;
  final ProductUnit unit;
  final Quantity initial;

  @override
  State<_ReorderPointDialog> createState() => _ReorderPointDialogState();
}

class _ReorderPointDialogState extends State<_ReorderPointDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial.toDecimalString());
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = Quantity.tryParse(_controller.text, unit: widget.unit);
    if (value == null) {
      setState(() => _error = widget.unit.allowsDecimals
          ? context.l10n.stock_invalidQuantity
          : context.l10n.stock_invalidWholeQuantity);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.stock_reorderPointTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.productName, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: l10n.stock_reorderPointLabel,
              helperText: l10n.stock_reorderPointHelper,
              suffixText: unitLabel(l10n, widget.unit),
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.common_save)),
      ],
    );
  }
}
