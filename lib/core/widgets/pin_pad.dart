import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/spacing.dart';

/// Numeric PIN entry (4–6 digits). Always LTR digit layout like a phone keypad.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.length = 4, this.errorText});

  final ValueChanged<String> onCompleted;
  final int length;
  final String? errorText;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';

  void _tap(String digit) {
    if (_pin.length >= widget.length) return;
    setState(() => _pin += digit);
    if (_pin.length == widget.length) {
      final value = _pin;
      setState(() => _pin = '');
      widget.onCompleted(value);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    Widget key(String d) => SizedBox.square(
          dimension: 72,
          child: TextButton(
            onPressed: () => _tap(d),
            child: Text(d, style: theme.textTheme.headlineSmall),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.common_pinTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < widget.length; i++)
              Container(
                margin: const EdgeInsets.all(AppSpacing.sm),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(widget.errorText!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: AppSpacing.lg),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in const [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(dimension: 72),
                  key('0'),
                  SizedBox.square(
                    dimension: 72,
                    child: IconButton(
                      tooltip: l10n.common_pinBackspace,
                      onPressed: _backspace,
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
