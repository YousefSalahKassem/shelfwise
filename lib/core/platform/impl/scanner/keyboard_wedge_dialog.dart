// OWNER: A5. Fallback for Windows/Linux, for devices without a usable camera,
// and for "type it by hand" everywhere else.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/spacing.dart';

/// Shows a focused field that a USB/Bluetooth barcode scanner can type into.
///
/// Those scanners behave like a keyboard: they type the code and press Enter,
/// which submits the field. Typing the code by hand works the same way.
/// Returns the code, or null if the user cancelled.
Future<String?> showKeyboardWedgeDialog(BuildContext context) => showDialog<String>(
      context: context,
      builder: (context) => const KeyboardWedgeDialog(),
    );

class KeyboardWedgeDialog extends StatefulWidget {
  const KeyboardWedgeDialog({super.key});

  @override
  State<KeyboardWedgeDialog> createState() => _KeyboardWedgeDialogState();
}

class _KeyboardWedgeDialogState extends State<KeyboardWedgeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.platform_wedgeTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            // Barcodes are digits and Latin letters, even in an Arabic UI.
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.text,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: InputDecoration(
              labelText: l10n.platform_wedgeHint,
              prefixIcon: const Icon(Icons.qr_code_scanner_outlined),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.platform_wedgeHelp,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty ? null : _submit,
          child: Text(l10n.platform_wedgeSubmit),
        ),
      ],
    );
  }
}
