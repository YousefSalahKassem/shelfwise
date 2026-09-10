import 'package:flutter/material.dart';

import '../../../../core/brand/brand_config.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import 'pin_entry.dart';

/// What the owner asked for in [ProfileFormSheet].
class ProfileFormResult {
  const ProfileFormResult({this.name, this.locale, this.pin});

  final String? name;

  /// Null means "same as the store".
  final String? locale;
  final String? pin;
}

enum ProfileFormMode { create, edit, resetPin }

/// Bottom sheet for adding a staff profile, editing one, or changing a PIN.
/// A new PIN is always entered twice.
class ProfileFormSheet extends StatefulWidget {
  const ProfileFormSheet({
    super.key,
    required this.mode,
    required this.brand,
    this.initialName = '',
    this.initialLocale,
  });

  final ProfileFormMode mode;
  final BrandConfig brand;
  final String initialName;
  final String? initialLocale;

  @override
  State<ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<ProfileFormSheet> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  late String? _locale = widget.initialLocale;
  late bool _pinStep = widget.mode == ProfileFormMode.resetPin;

  String? _firstPin;
  String? _nameError;
  String? _pinError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _continue() {
    final l10n = context.l10n;
    if (_name.text.trim().isEmpty) {
      setState(() => _nameError = l10n.profiles_errorName);
      return;
    }
    if (widget.mode == ProfileFormMode.edit) {
      Navigator.of(context).pop(
        ProfileFormResult(name: _name.text.trim(), locale: _locale),
      );
      return;
    }
    setState(() {
      _nameError = null;
      _pinStep = true;
    });
  }

  void _onPin(String pin) {
    final first = _firstPin;
    if (first == null) {
      setState(() {
        _firstPin = pin;
        _pinError = null;
      });
      return;
    }
    if (first != pin) {
      setState(() {
        _firstPin = null;
        _pinError = context.l10n.profiles_pinMismatch;
      });
      return;
    }
    Navigator.of(context).pop(
      ProfileFormResult(name: _name.text.trim(), locale: _locale, pin: pin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = switch (widget.mode) {
      ProfileFormMode.create => l10n.profiles_addTitle,
      ProfileFormMode.edit => l10n.profiles_editTitle,
      ProfileFormMode.resetPin => l10n.profiles_resetPin,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xl),
            if (_pinStep)
              PinEntry(
                label: _firstPin == null ? l10n.common_pinTitle : l10n.profiles_pinRepeat,
                errorText: _pinError,
                onSubmit: _onPin,
              )
            else ...[
              TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.profiles_name,
                  errorText: _nameError,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String?>(
                initialValue: _locale,
                decoration: InputDecoration(labelText: l10n.profiles_language),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.profiles_languageStore)),
                  for (final locale in widget.brand.supportedLocales)
                    DropdownMenuItem(
                      value: locale.languageCode,
                      child: Text(
                        locale.languageCode == 'ar'
                            ? l10n.common_languageArabic
                            : l10n.common_languageEnglish,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _locale = value),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _continue,
                child: Text(
                  widget.mode == ProfileFormMode.edit ? l10n.common_save : l10n.common_add,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
