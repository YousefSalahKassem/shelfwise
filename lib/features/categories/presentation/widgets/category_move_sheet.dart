import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import 'category_messages.dart';

/// Picks the top-level category to move [moving] into. Returns its id, or null
/// if cancelled. Only top-level categories are offered (max depth 2).
Future<String?> showCategoryMoveSheet(
  BuildContext context, {
  required Category moving,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => _CategoryMoveSheet(moving: moving),
  );
}

class _CategoryMoveSheet extends ConsumerWidget {
  const _CategoryMoveSheet({required this.moving});

  final Category moving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final parents = ref
        .watch(categoryOptionsProvider)
        .where((o) => !o.isChild && o.id != moving.id)
        .toList(growable: false);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l10n.catalogue_categoryMoveInto,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (parents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(l10n.catalogue_categoryEmptyTitle),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in parents)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(option.name),
                      onTap: () => Navigator.of(context).pop(option.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Deletes a category, asking where its products should go when it isn't empty.
Future<void> showCategoryDeleteFlow(
  BuildContext context,
  WidgetRef ref, {
  required Category category,
}) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.catalogue_categoryDeleteTitle(category.name)),
      content: Text(l10n.catalogue_categoryDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.common_cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.common_delete),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  var result = await ref.read(deleteCategoryProvider)(category.id);
  final failure = result.failureOrNull;
  final blockedByProducts = failure != null &&
      failure is ValidationFailure &&
      failure.code == 'not_empty';

  if (blockedByProducts && context.mounted) {
    final targetId = await _askMoveTarget(context, category: category);
    if (targetId == null || !context.mounted) return;
    result = await ref.read(deleteCategoryProvider)(
      category.id,
      moveProductsTo: targetId,
    );
  }
  if (context.mounted) showCategoryResult(context, result);
}

/// Asks which category the products should move to before deleting.
Future<String?> _askMoveTarget(
  BuildContext context, {
  required Category category,
}) async {
  final l10n = context.l10n;
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final options = ref
            .watch(categoryOptionsProvider)
            .where((o) => o.id != category.id && o.parentId != category.id)
            .toList(growable: false);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.catalogue_categoryMoveProductsTo,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.catalogue_categoryHasProducts,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        leading: Icon(
                          option.isChild
                              ? Icons.subdirectory_arrow_right
                              : Icons.folder_outlined,
                        ),
                        title: Text(option.fullName),
                        onTap: () => Navigator.of(ctx).pop(option.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}