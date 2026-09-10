import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/validation.dart';

/// Asks for a category name. Returns the trimmed name, or null if cancelled.
Future<String?> showCategoryNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? parentName,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CategoryNameDialog(
      title: title,
      initialValue: initialValue,
      parentName: parentName,
    ),
  );
}

class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({
    required this.title,
    required this.initialValue,
    this.parentName,
  });

  final String title;
  final String initialValue;
  final String? parentName;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: CategoryValidation.maxNameLength,
          decoration: InputDecoration(
            labelText: l10n.catalogue_categoryNameLabel,
            helperText: widget.parentName == null
                ? null
                : '${l10n.catalogue_categoryParentLabel}: ${widget.parentName}',
          ),
          validator: (value) {
            final name = (value ?? '').trim();
            if (name.isEmpty) return l10n.catalogue_categoryNameRequired;
            if (name.length > CategoryValidation.maxNameLength) {
              return l10n.catalogue_categoryNameTooLong;
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
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
