import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/widgets/money_text.dart';
import '../../../../core/widgets/stock_badge.dart';
import '../../domain/entities/product.dart';
import '../providers/product_providers.dart';

/// One product row: photo, name, category/SKU, stock badge and price.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.summary, this.onTap, this.dense = false});

  final ProductSummary summary;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final product = summary.product;
    final theme = Theme.of(context);
    final subtitle = [
      if (summary.categoryName != null) summary.categoryName!,
      if (product.sku != null) product.sku!,
      if (product.isArchived) l10n.catalogue_archived,
    ].join(' · ');

    return ListTile(
      onTap: onTap,
      dense: dense,
      leading: ProductThumbnail(product: product),
      title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          MoneyText(product.price, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xxs),
          StockBadge(summary.status),
        ],
      ),
    );
  }
}

/// Stored thumbnail, or a neutral placeholder while it loads / when there is none.
class ProductThumbnail extends ConsumerWidget {
  const ProductThumbnail({super.key, required this.product, this.size = 44});

  final Product product;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: size / 2,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    if (!product.hasImage) return placeholder;

    final bytes = ref.watch(productImageProvider(product.id)).value;
    if (bytes == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
