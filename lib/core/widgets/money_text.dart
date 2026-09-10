import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/effective_locale.dart';
import '../utils/money.dart';
import '../utils/quantity.dart';

class MoneyText extends ConsumerWidget {
  const MoneyText(this.money, {super.key, this.style, this.withSymbol = true});
  final Money money;
  final TextStyle? style;
  final bool withSymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(appFormattersProvider);
    return Text(
      f.money(money, withSymbol: withSymbol),
      style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

class QuantityText extends ConsumerWidget {
  const QuantityText(this.quantity, {super.key, this.unitLabel, this.style});
  final Quantity quantity;
  final String? unitLabel;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(appFormattersProvider);
    final text = unitLabel == null ? f.quantity(quantity) : '${f.quantity(quantity)} $unitLabel';
    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
