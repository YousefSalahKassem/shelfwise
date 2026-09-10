import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/entities/pricing.dart';
import '../providers/pricing_providers.dart';
import '../widgets/margin_line.dart';
import '../widgets/pricing_nav.dart';

/// `/prices/:productId` — change one product's price (and optionally its cost),
/// with the margin updating as you type. Owner only (router guard + use case).
class SinglePricePage extends ConsumerWidget {
  const SinglePricePage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final pricing = ref.watch(productPricingProvider(productId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pricing_editTitle)),
      body: switch (pricing) {
        AsyncData(:final value) => _PriceForm(pricing: value),
        AsyncError(:final error) => ErrorView(
            error: error,
            onRetry: () => ref.invalidate(productPricingProvider(productId)),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PriceForm extends ConsumerStatefulWidget {
  const _PriceForm({required this.pricing});

  final PriceChangePreview pricing;

  @override
  ConsumerState<_PriceForm> createState() => _PriceFormState();
}

class _PriceFormState extends ConsumerState<_PriceForm> {
  late final TextEditingController _price =
      TextEditingController(text: widget.pricing.oldPrice.toDecimalString());
  late final TextEditingController _cost =
      TextEditingController(text: widget.pricing.oldCost.toDecimalString());
  bool _saving = false;
  bool _submitted = false;

  @override
  void dispose() {
    _price.dispose();
    _cost.dispose();
    super.dispose();
  }

  String get _currency => widget.pricing.oldPrice.currency;

  Money? get _newPrice => Money.tryParse(_price.text, _currency);
  Money? get _newCost => Money.tryParse(_cost.text, _currency);

  Future<void> _save() async {
    setState(() => _submitted = true);
    final price = _newPrice;
    final cost = _newCost;
    if (price == null || cost == null) return;

    setState(() => _saving = true);
    final result = await ref.read(updatePriceProvider)(
      widget.pricing.productId,
      price: price,
      cost: cost,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case Success<void>():
        messenger.showSnackBar(SnackBar(content: Text(l10n.pricing_saved)));
        leaveScreen(context, RoutePaths.productDetailFor(widget.pricing.productId));
      case Err<void>(:final Failure failure):
        messenger.showSnackBar(SnackBar(content: Text(failureMessage(l10n, failure))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final price = _newPrice;
    final cost = _newCost;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(widget.pricing.productName, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(l10n.pricing_currentPrice, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.sm),
            MoneyText(widget.pricing.oldPrice, style: theme.textTheme.bodyMedium),
            const SizedBox(width: AppSpacing.lg),
            Flexible(
              child: Text(
                l10n.pricing_costLabel(widget.pricing.oldCost.toDecimalString()),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        TextField(
          controller: _price,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.pricing_newPrice,
            border: const OutlineInputBorder(),
            errorText: _submitted && price == null ? l10n.pricing_invalidPrice : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _cost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.pricing_newCost,
            border: const OutlineInputBorder(),
            errorText: _submitted && cost == null ? l10n.pricing_invalidCost : null,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        const SizedBox(height: AppSpacing.lg),
        MarginLine(
          price: price ?? widget.pricing.oldPrice,
          cost: cost ?? widget.pricing.oldCost,
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? l10n.common_loading : l10n.pricing_savePrice),
        ),
      ],
    );
  }
}
