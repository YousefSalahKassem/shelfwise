import 'package:flutter/material.dart';

/// Semantic stock colours. Fixed for every brand (AD-8) and tuned for
/// WCAG AA on their container colours in both themes.
@immutable
class StockColors extends ThemeExtension<StockColors> {
  const StockColors({
    required this.ok,
    required this.onOk,
    required this.okContainer,
    required this.low,
    required this.onLow,
    required this.lowContainer,
    required this.out,
    required this.onOut,
    required this.outContainer,
  });

  final Color ok, onOk, okContainer;
  final Color low, onLow, lowContainer;
  final Color out, onOut, outContainer;

  static const light = StockColors(
    ok: Color(0xFF1B6B3A),
    onOk: Color(0xFFFFFFFF),
    okContainer: Color(0xFFD7F0DF),
    low: Color(0xFF8A5300),
    onLow: Color(0xFFFFFFFF),
    lowContainer: Color(0xFFFCE8C8),
    out: Color(0xFFB3261E),
    onOut: Color(0xFFFFFFFF),
    outContainer: Color(0xFFF9DEDC),
  );

  static const dark = StockColors(
    ok: Color(0xFF7ED8A0),
    onOk: Color(0xFF00391A),
    okContainer: Color(0xFF14432A),
    low: Color(0xFFF2B866),
    onLow: Color(0xFF442900),
    lowContainer: Color(0xFF4A3212),
    out: Color(0xFFF2B8B5),
    onOut: Color(0xFF601410),
    outContainer: Color(0xFF5C1A15),
  );

  static StockColors of(BuildContext context) =>
      Theme.of(context).extension<StockColors>() ?? light;

  @override
  StockColors copyWith({
    Color? ok,
    Color? onOk,
    Color? okContainer,
    Color? low,
    Color? onLow,
    Color? lowContainer,
    Color? out,
    Color? onOut,
    Color? outContainer,
  }) =>
      StockColors(
        ok: ok ?? this.ok,
        onOk: onOk ?? this.onOk,
        okContainer: okContainer ?? this.okContainer,
        low: low ?? this.low,
        onLow: onLow ?? this.onLow,
        lowContainer: lowContainer ?? this.lowContainer,
        out: out ?? this.out,
        onOut: onOut ?? this.onOut,
        outContainer: outContainer ?? this.outContainer,
      );

  @override
  StockColors lerp(StockColors? other, double t) {
    if (other == null) return this;
    return StockColors(
      ok: Color.lerp(ok, other.ok, t)!,
      onOk: Color.lerp(onOk, other.onOk, t)!,
      okContainer: Color.lerp(okContainer, other.okContainer, t)!,
      low: Color.lerp(low, other.low, t)!,
      onLow: Color.lerp(onLow, other.onLow, t)!,
      lowContainer: Color.lerp(lowContainer, other.lowContainer, t)!,
      out: Color.lerp(out, other.out, t)!,
      onOut: Color.lerp(onOut, other.onOut, t)!,
      outContainer: Color.lerp(outContainer, other.outContainer, t)!,
    );
  }
}
