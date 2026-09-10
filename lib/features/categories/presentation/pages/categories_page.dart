import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/permission.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../domain/entities/category.dart';
import '../providers/category_providers.dart';
import '../widgets/category_form_dialog.dart';
import '../widgets/category_messages.dart';
import '../widgets/category_move_sheet.dart';

/// Two-level category tree: add, rename, reorder, move and delete.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final tree = ref.watch(categoryTreeProvider);
    final canEdit = ref.watch(sessionControllerProvider).can(Permission.editCatalogue);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogue_categoriesTitle)),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined),
              label: Text(l10n.catalogue_categoryAdd),
            )
          : null,
      body: switch (tree) {
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(categoryTreeProvider),
          ),
        AsyncData(:final value) when value.isEmpty => EmptyState(
            icon: Icons.category_outlined,
            title: l10n.catalogue_categoryEmptyTitle,
            message: l10n.catalogue_categoryEmptyBody,
            action: canEdit
                ? FilledButton.icon(
                    onPressed: () => _add(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.catalogue_categoryAdd),
                  )
                : null,
          ),
        AsyncData(:final value) => _CategoryTree(nodes: value, canEdit: canEdit),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, {CategoryNode? parent}) async {
    final l10n = context.l10n;
    final name = await showCategoryNameDialog(
      context,
      title: parent == null ? l10n.catalogue_categoryAdd : l10n.catalogue_categorySubAdd,
      parentName: parent?.category.name,
    );
    if (name == null || !context.mounted) return;
    final result =
        await ref.read(createCategoryProvider)(name, parentId: parent?.category.id);
    if (context.mounted) showCategoryResult(context, result);
  }
}

class _CategoryTree extends ConsumerWidget {
  const _CategoryTree({required this.nodes, required this.canEdit});

  final List<CategoryNode> nodes;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl * 2),
      itemCount: nodes.length,
      itemBuilder: (context, index) => _CategoryGroup(
        node: nodes[index],
        canEdit: canEdit,
        index: index,
        lastIndex: nodes.length - 1,
      ),
    );
  }
}

class _CategoryGroup extends ConsumerWidget {
  const _CategoryGroup({
    required this.node,
    required this.canEdit,
    required this.index,
    required this.lastIndex,
  });

  final CategoryNode node;
  final bool canEdit;
  final int index;
  final int lastIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subtitle = [
      l10n.catalogue_categoryProductCount(node.productCount),
      if (node.children.isNotEmpty) l10n.catalogue_categorySubCount(node.children.length),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(node.category.name),
          subtitle: Text(subtitle),
          trailing: canEdit
              ? _CategoryMenu(
                  category: node.category,
                  canMoveUp: index > 0,
                  canMoveDown: index < lastIndex,
                  hasChildren: node.children.isNotEmpty,
                  siblingIndex: index,
                )
              : null,
        ),
        for (var i = 0; i < node.children.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: AppSpacing.xxl),
            child: _CategoryChildTile(
              category: node.children[i],
              canEdit: canEdit,
              index: i,
              lastIndex: node.children.length - 1,
            ),
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xxl + AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _addChild(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.catalogue_categorySubAdd),
              ),
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final name = await showCategoryNameDialog(
      context,
      title: context.l10n.catalogue_categorySubAdd,
      parentName: node.category.name,
    );
    if (name == null || !context.mounted) return;
    final result = await ref.read(createCategoryProvider)(name, parentId: node.category.id);
    if (context.mounted) showCategoryResult(context, result);
  }
}

class _CategoryChildTile extends StatelessWidget {
  const _CategoryChildTile({
    required this.category,
    required this.canEdit,
    required this.index,
    required this.lastIndex,
  });

  final Category category;
  final bool canEdit;
  final int index;
  final int lastIndex;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
        title: Text(category.name),
        trailing: canEdit
            ? _CategoryMenu(
                category: category,
                canMoveUp: index > 0,
                canMoveDown: index < lastIndex,
                hasChildren: false,
                siblingIndex: index,
              )
            : null,
      );
}

enum _CategoryAction { rename, moveUp, moveDown, move, delete }

class _CategoryMenu extends ConsumerWidget {
  const _CategoryMenu({
    required this.category,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.hasChildren,
    required this.siblingIndex,
  });

  final Category category;
  final bool canMoveUp;
  final bool canMoveDown;
  final bool hasChildren;
  final int siblingIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PopupMenuButton<_CategoryAction>(
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => _run(context, ref, action),
      itemBuilder: (context) => [
        PopupMenuItem(value: _CategoryAction.rename, child: Text(l10n.common_edit)),
        if (canMoveUp)
          PopupMenuItem(
            value: _CategoryAction.moveUp,
            child: Text(l10n.catalogue_categoryMoveUp),
          ),
        if (canMoveDown)
          PopupMenuItem(
            value: _CategoryAction.moveDown,
            child: Text(l10n.catalogue_categoryMoveDown),
          ),
        PopupMenuItem(
          value: _CategoryAction.move,
          child: Text(category.parentId == null
              ? l10n.catalogue_categoryMoveInto
              : l10n.catalogue_categoryMakeTopLevel),
        ),
        PopupMenuItem(value: _CategoryAction.delete, child: Text(l10n.common_delete)),
      ],
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, _CategoryAction action) async {
    switch (action) {
      case _CategoryAction.rename:
        final name = await showCategoryNameDialog(
          context,
          title: context.l10n.catalogue_categoryEditTitle,
          initialValue: category.name,
        );
        if (name == null || !context.mounted) return;
        final result = await ref.read(renameCategoryProvider)(category.id, name);
        if (context.mounted) showCategoryResult(context, result);
      case _CategoryAction.moveUp:
        await _move(context, ref, parentId: category.parentId, sortOrder: siblingIndex - 1);
      case _CategoryAction.moveDown:
        await _move(context, ref, parentId: category.parentId, sortOrder: siblingIndex + 1);
      case _CategoryAction.move:
        if (category.parentId != null) {
          await _move(context, ref, parentId: null, sortOrder: 0);
          return;
        }
        if (hasChildren) {
          showCategoryMessage(context, context.l10n.catalogue_categoryMaxDepth);
          return;
        }
        final parentId = await showCategoryMoveSheet(context, moving: category);
        if (parentId == null || !context.mounted) return;
        await _move(context, ref, parentId: parentId, sortOrder: 0);
      case _CategoryAction.delete:
        await showCategoryDeleteFlow(context, ref, category: category);
    }
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref, {
    required String? parentId,
    required int sortOrder,
  }) async {
    final result = await ref.read(moveCategoryProvider)(
      category.id,
      parentId: parentId,
      sortOrder: sortOrder < 0 ? 0 : sortOrder,
    );
    if (context.mounted) showCategoryResult(context, result);
  }
}
