import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../providers/category_providers.dart';

/// Category chooser for forms and filters: a flat dropdown where
/// sub-categories are shown indented under their parent.
///
/// Exported through `categories/public.dart` so other features (product form,
/// pricing, import) can reuse it without importing this feature's internals.
class CategoryField extends ConsumerWidget {
  const CategoryField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.noneLabel,
    this.excludeId,
    this.enabled = true,
  });

  /// Selected category id, or null for "no category".
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? label;

  /// Text of the "no category" entry (a filter says "All categories").
  final String? noneLabel;

  /// Hides one category and its children — used when moving products out of it.
  final String? excludeId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final options = ref
        .watch(categoryOptionsProvider)
        .where((o) => o.id != excludeId && (excludeId == null || o.parentId != excludeId))
        .toList(growable: false);
    final known = options.any((o) => o.id == value);

    return DropdownButtonFormField<String?>(
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label ?? l10n.catalogue_fieldCategory,
        prefixIcon: const Icon(Icons.category_outlined),
      ),
      items: [
        DropdownMenuItem<String?>(
          child: Text(noneLabel ?? l10n.catalogue_categoryNone),
        ),
        for (final option in options)
          DropdownMenuItem<String?>(
            value: option.id,
            child: Padding(
              padding: EdgeInsetsDirectional.only(start: option.isChild ? 16 : 0),
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
