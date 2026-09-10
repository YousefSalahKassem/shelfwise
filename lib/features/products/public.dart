// OWNER: A2. Public surface of the products feature.
import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import 'domain/entities/product.dart';

export 'domain/entities/product.dart';

/// Search-or-scan product chooser used by stock, pricing and dashboard.
/// W0 stub: shows an info dialog and returns null.
Future<Product?> showProductPicker(BuildContext context) async {
  final l10n = context.l10n;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.catalogue_pickerTitle),
      content: Text(l10n.common_placeholderBody),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l10n.common_ok))],
    ),
  );
  return null;
}
