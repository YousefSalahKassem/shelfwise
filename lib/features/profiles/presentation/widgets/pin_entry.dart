import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/value_objects/pin.dart';

/// Keypad for a PIN of [Pin.minLength]–[Pin.maxLength] digits.
///
/// Unlike a fixed-length pad it cannot submit on its own, so it shows a confirm
/// key that lights up once enough digits are entered. The keypad is always laid
/// out left-to-right, like a phone, in both languages.
class PinEntry extends StatefulWidget {
  const PinEntry({
    super.key,
    required this.onSubmit,
    this.label,
    this.errorText,
    this.enabled = true,
  });

  final ValueChanged<String> onSubmit;
  final String? label;
  final String? errorText;
  final bool enabled;

  @override
  State<PinEntry> createState() => PinEntryState();
}

class PinEntryState extends State<PinEntry> {
  String _pin = '';

  /// Clears the pad — used when a second entry is asked for (confirm PIN).
  void clear() => setState(() => _pin = '');

  void _tap(String digit) {
    if (_pin.length >= Pin.maxLength) return;
    setState(() => _pin += digit);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_pin.length < Pin.minLength) return;
    final value = _pin;
    setState(() => _pin = '');
    widget.onSubmit(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final enabled = widget.enabled;

    Widget key(String digit) => SizedBox.square(
          dimension: AppSpacing.minTarget + AppSpacing.lg,
          child: TextButton(
            onPressed: enabled ? () => _tap(digit) : null,
            child: Text(digit, style: theme.textTheme.headlineSmall),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label ?? l10n.common_pinTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profiles_pinHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < Pin.maxLength; i++)
              Container(
                margin: const EdgeInsets.all(AppSpacing.sm),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              widget.errorText!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.error),
            ),
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
                  SizedBox.square(
                    dimension: AppSpacing.minTarget + AppSpacing.lg,
                    child: IconButton(
                      tooltip: l10n.common_pinBackspace,
                      onPressed: enabled && _pin.isNotEmpty ? _backspace : null,
                      icon: const Icon(Icons.backspace_outlined),
                    ),
                  ),
                  key('0'),
                  SizedBox.square(
                    dimension: AppSpacing.minTarget + AppSpacing.lg,
                    child: IconButton.filled(
                      tooltip: l10n.common_confirm,
                      onPressed: enabled && _pin.length >= Pin.minLength ? _submit : null,
                      icon: const Icon(Icons.check),
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
