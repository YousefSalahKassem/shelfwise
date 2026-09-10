import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';

/// Photo picker for the product form: shows the current thumbnail (or a
/// placeholder) with add / replace / remove actions.
class ProductImageField extends StatelessWidget {
  const ProductImageField({
    super.key,
    required this.bytes,
    required this.onPick,
    required this.onRemove,
    this.busy = false,
  });

  final Uint8List? bytes;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final image = bytes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            width: 88,
            height: 88,
            child: busy
                ? const Center(child: CircularProgressIndicator())
                : image == null
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Image.memory(image, fit: BoxFit.cover, gaplessPlayback: true),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.catalogue_fieldPhoto, style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onPick,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(
                      image == null ? l10n.catalogue_photoAdd : l10n.catalogue_photoReplace,
                    ),
                  ),
                  if (image != null)
                    TextButton(
                      onPressed: busy ? null : onRemove,
                      child: Text(l10n.catalogue_photoRemove),
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
