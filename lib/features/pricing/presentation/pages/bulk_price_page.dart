import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/failure_messages.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../products/public.dart';
import '../../domain/entities/pricing.dart';
import '../providers/bulk_price_controller.dart';
import '../providers/pricing_providers.dart';
import '../widgets/preview_tile.dart';
import '../widgets/pricing_nav.dart';

/// `/prices/bulk` — reprice a whole category (or a chosen set of products) in
/// three steps: describe the change, check the preview, apply. Owner only.
///
/// `?ids=a,b` preselects products so the catalogue can link straight into a
/// selection without a new route constant.
class BulkPricePage extends ConsumerWidget {
  const BulkPricePage({super.key, this.initialIds = ''});

  /// Raw `?ids=` query parameter.
  final String initialIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(bulkPriceControllerProvider(initialIds));
    final controller = ref.read(bulkPriceControllerProvider(initialIds).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.phase == BulkPhase.done ? l10n.pricing_summaryTitle : l10n.pricing_bulkTitle),
        leading: state.phase == BulkPhase.preview
            ? IconButton(
                icon: const BackButtonIcon(),
                tooltip: l10n.pricing_back,
                onPressed: controller.backToForm,
              )
            : null,
      ),
      body: switch (state.phase) {
        BulkPhase.form => _FormView(state: state, controller: controller),
        BulkPhase.preview => _PreviewView(state: state, controller: controller),
        BulkPhase.done => _SummaryView(state: state),
      },
    );
  }
}

class _FormView extends ConsumerWidget {
  const _FormView({required this.state, required this.controller});

  final BulkPriceState state;
  final BulkPriceController controller;

  Future<void> _pickProducts(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final product = await showProductPicker(context);
    if (product == null) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.pricing_pickerUnavailable)));
      return;
    }
    controller.addProduct(product.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final currency = ref.watch(storeCurrencyProvider);
    final categories = ref.watch(pricingCategoriesProvider).value ?? const [];
    final tops = categories.where((c) => c.parentId == null).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _SectionTitle(l10n.pricing_scope),
        SegmentedButton<BulkScope>(
          segments: [
            ButtonSegment(value: BulkScope.category, label: Text(l10n.pricing_scopeCategory)),
            ButtonSegment(value: BulkScope.selection, label: Text(l10n.pricing_scopeSelection)),
          ],
          selected: {state.scope},
          onSelectionChanged: (s) => controller.setScope(s.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (state.scope == BulkScope.category) ...[
          DropdownButtonFormField<String>(
            key: const Key('pricing_categoryField'),
            initialValue: state.categoryId,
            decoration: InputDecoration(
              labelText: l10n.pricing_chooseCategory,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final top in tops) ...[
                DropdownMenuItem(value: top.id, child: Text(top.name)),
                for (final child in categories.where((c) => c.parentId == top.id))
                  DropdownMenuItem(
                    value: child.id,
                    child: Text('${top.name} › ${child.name}'),
                  ),
              ],
            ],
            onChanged: controller.setCategory,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.pricing_includeSubcategories),
            value: state.includeSubcategories,
            onChanged: controller.setIncludeSubcategories,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.pricing_selectedProducts(formatters.number(state.productIds.length)),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              if (state.productIds.isNotEmpty)
                TextButton(
                  onPressed: () => controller.setProductIds(const []),
                  child: Text(l10n.pricing_clearSelection),
                ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: () => _pickProducts(context, ref),
                icon: const Icon(Icons.add),
                label: Text(l10n.pricing_addProducts),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle(l10n.pricing_change),
        SegmentedButton<BulkMode>(
          segments: [
            ButtonSegment(value: BulkMode.percent, label: Text(l10n.pricing_modePercent)),
            ButtonSegment(value: BulkMode.fixed, label: Text(l10n.pricing_modeAmount)),
          ],
          selected: {state.mode},
          onSelectionChanged: (s) => controller.setMode(s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.trending_up),
              label: Text(l10n.pricing_increase),
            ),
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.trending_down),
              label: Text(l10n.pricing_decrease),
            ),
          ],
          selected: {state.increase},
          onSelectionChanged: (s) => controller.setIncrease(s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          key: const Key('pricing_amountField'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: state.mode == BulkMode.percent
                ? l10n.pricing_amountPercent
                : l10n.pricing_amountFixed,
            suffixText: state.mode == BulkMode.percent ? '%' : currency,
            border: const OutlineInputBorder(),
            errorText: state.formError == 'amount' ? l10n.pricing_errorAmount : null,
          ),
          onChanged: controller.setAmountText,
        ),
        if (state.formError == 'scope')
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.pricing_errorScope,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        _SectionTitle(l10n.pricing_target),
        SegmentedButton<PriceTarget>(
          segments: [
            ButtonSegment(value: PriceTarget.price, label: Text(l10n.pricing_targetPrice)),
            ButtonSegment(value: PriceTarget.cost, label: Text(l10n.pricing_targetCost)),
            ButtonSegment(value: PriceTarget.both, label: Text(l10n.pricing_targetBoth)),
          ],
          selected: {state.target},
          onSelectionChanged: (s) => controller.setTarget(s.first),
        ),
        if (state.target != PriceTarget.cost) ...[
          const SizedBox(height: AppSpacing.xl),
          _SectionTitle(l10n.pricing_rounding),
          DropdownButtonFormField<RoundingStep>(
            key: const Key('pricing_roundingField'),
            initialValue: state.rounding,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final step in RoundingStep.values)
                DropdownMenuItem(
                  value: step,
                  child: Text(
                    step == RoundingStep.none
                        ? l10n.pricing_roundingNone
                        : formatters.money(Money(step.minorStep, currency), withSymbol: false),
                  ),
                ),
            ],
            onChanged: (v) => controller.setRounding(v ?? RoundingStep.none),
          ),
          if (state.rounding != RoundingStep.none) ...[
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<RoundingMode>(
              segments: [
                ButtonSegment(value: RoundingMode.nearest, label: Text(l10n.pricing_roundNearest)),
                ButtonSegment(value: RoundingMode.up, label: Text(l10n.pricing_roundUp)),
              ],
              selected: {state.roundingMode},
              onSelectionChanged: (s) => controller.setRoundingMode(s.first),
            ),
          ],
        ],
        if (state.failure != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            failureMessage(l10n, state.failure!),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        FilledButton.icon(
          onPressed: state.busy ? null : controller.loadPreview,
          icon: const Icon(Icons.visibility_outlined),
          label: Text(state.busy ? l10n.common_loading : l10n.pricing_showPreview),
        ),
      ],
    );
  }
}

class _PreviewView extends ConsumerWidget {
  const _PreviewView({required this.state, required this.controller});

  final BulkPriceState state;
  final BulkPriceController controller;

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final count = ref.read(appFormattersProvider).number(state.changed.length);
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.pricing_applyConfirmTitle,
      message: l10n.pricing_applyConfirmBody(count),
      confirmLabel: l10n.pricing_apply,
    );
    if (!confirmed) return;
    await controller.apply();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final changed = state.changed;

    if (state.preview.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: l10n.pricing_noProducts,
        action: OutlinedButton(onPressed: controller.backToForm, child: Text(l10n.pricing_back)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.pricing_previewCount(formatters.number(changed.length)),
                style: theme.textTheme.titleMedium,
              ),
              if (state.belowCostCount > 0 || state.zeroCount > 0)
                Text(
                  l10n.pricing_previewWarnings(
                    formatters.number(state.belowCostCount),
                    formatters.number(state.zeroCount),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              if (state.failure != null)
                Text(
                  failureMessage(l10n, state.failure!),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            itemCount: state.preview.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => PreviewTile(preview: state.preview[i]),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.busy ? null : controller.backToForm,
                    child: Text(l10n.pricing_back),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: state.busy || changed.isEmpty ? null : () => _apply(context, ref),
                    child: Text(state.busy ? l10n.common_loading : l10n.pricing_apply),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryView extends ConsumerWidget {
  const _SummaryView({required this.state});

  final BulkPriceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final formatters = ref.watch(appFormattersProvider);
    final result = state.result;
    final average = result?.averagePercent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              Icon(Icons.price_change_outlined, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.pricing_summaryCount(formatters.number(result?.count ?? 0)),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                average == null
                    ? l10n.pricing_summaryUpDown(
                        formatters.number(result?.increased ?? 0),
                        formatters.number(result?.decreased ?? 0),
                      )
                    : '${l10n.pricing_summaryAverage(formatters.percent(average))} · '
                        '${l10n.pricing_summaryUpDown(formatters.number(result?.increased ?? 0), formatters.number(result?.decreased ?? 0))}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: [
              ExpansionTile(
                initiallyExpanded: true,
                title: Text(l10n.pricing_viewChanges),
                children: [
                  for (final p in state.changed) PreviewTile(preview: p),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => leaveScreen(context, RoutePaths.products),
                child: Text(l10n.pricing_done),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}
