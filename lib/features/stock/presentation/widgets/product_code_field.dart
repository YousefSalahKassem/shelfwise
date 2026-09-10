// OWNER: A4. Scan-first product entry: a USB/Bluetooth scanner types into the
// field and presses Enter, the camera button covers phones, and the picker is
// there when the barcode is missing or unreadable.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/impl/platform_providers.dart';
import '../../../../core/theme/spacing.dart';
import '../../../products/public.dart';
import '../../domain/entities/stock_view.dart';
import '../providers/stock_providers.dart';

class ProductCodeField extends ConsumerStatefulWidget {
  const ProductCodeField({
    super.key,
    required this.onProduct,
    this.hintText,
    this.autofocus = true,
  });

  /// Called with the resolved product; the field clears and refocuses itself.
  final ValueChanged<ProductStock> onProduct;
  final String? hintText;
  final bool autofocus;

  @override
  ConsumerState<ProductCodeField> createState() => ProductCodeFieldState();
}

class ProductCodeFieldState extends ConsumerState<ProductCodeField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Keeps the scanner loop going: clear, refocus, ready for the next scan.
  void focus() {
    if (mounted) _focus.requestFocus();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || _busy) return;
    setState(() => _busy = true);
    final result = await ref.read(getStockProvider).findByCode(trimmed);
    if (!mounted) return;
    setState(() => _busy = false);
    _controller.clear();
    focus();
    result.fold(
      (product) {
        if (product == null) {
          _message(context.l10n.stock_codeNotFound(trimmed));
        } else {
          widget.onProduct(product);
        }
      },
      (failure) => _message(context.l10n.stock_lookupFailed),
    );
  }

  Future<void> _scan() async {
    final code = await ref.read(scannerServiceProvider).scan(context);
    if (code != null) await _submit(code);
  }

  Future<void> _pick() async {
    final product = await showProductPicker(context);
    if (product == null || !mounted) return;
    final result = await ref.read(getStockProvider).productStock(product.id);
    if (!mounted) return;
    result.fold(widget.onProduct, (failure) => _message(context.l10n.stock_lookupFailed));
    focus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scanner = ref.watch(scannerServiceProvider);
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.qr_code_2),
              labelText: widget.hintText ?? l10n.stock_codeLabel,
              helperText: l10n.stock_codeHelper,
              border: const OutlineInputBorder(),
              suffixIcon: _busy
                  ? const Padding(
                      padding: EdgeInsetsDirectional.all(AppSpacing.md),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      tooltip: l10n.stock_codeSubmit,
                      onPressed: () => _submit(_controller.text),
                    ),
            ),
          ),
        ),
        if (scanner.supportsCamera) ...[
          const SizedBox(width: AppSpacing.sm),
          IconButton.filledTonal(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: l10n.stock_scan,
          ),
        ],
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: _busy ? null : _pick,
          icon: const Icon(Icons.search),
          tooltip: l10n.stock_findProduct,
        ),
      ],
    );
  }
}
