import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';

/// Debounced search box that also works as a **keyboard wedge**: a USB or
/// Bluetooth scanner types the code and sends Enter, which fires [onSubmitted]
/// with the full code (Windows, Linux and any desktop browser).
class ProductSearchField extends StatefulWidget {
  const ProductSearchField({
    super.key,
    required this.onChanged,
    this.onSubmitted,
    this.initialValue = '',
    this.hintText,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 250),
    this.trailing,
  });

  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final String initialValue;
  final String? hintText;
  final bool autofocus;
  final Duration debounce;
  final Widget? trailing;

  @override
  State<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends State<ProductSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value));
    setState(() {});
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: _onChanged,
      onSubmitted: (value) {
        _timer?.cancel();
        widget.onChanged(value);
        widget.onSubmitted?.call(value.trim());
      },
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        hintText: widget.hintText ?? l10n.catalogue_searchHint,
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: l10n.common_close,
                onPressed: _clear,
              ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}
