import 'package:meta/meta.dart';

import 'money.dart' show normalizeDigits;

/// Unit a product is counted in. Weight/volume units allow decimals.
enum ProductUnit {
  piece,
  kg,
  g,
  l,
  ml,
  box,
  pack;

  bool get allowsDecimals => this == kg || this == l;

  static ProductUnit fromName(String name) => ProductUnit.values
      .firstWhere((u) => u.name == name, orElse: () => ProductUnit.piece);
}

/// A stock quantity stored as integer thousandths (2.5 kg → 2500).
@immutable
class Quantity implements Comparable<Quantity> {
  const Quantity(this.milli);
  const Quantity.zero() : milli = 0;
  const Quantity.whole(int units) : milli = units * scale;

  final int milli;
  static const int scale = 1000;

  /// Parses `2`, `2.5`, `2,5`, `٢٫٥`. Returns null for invalid input or when
  /// [unit] doesn't allow decimals and the value has a fraction.
  static Quantity? tryParse(
    String input, {
    ProductUnit unit = ProductUnit.piece,
    bool allowNegative = false,
  }) {
    var s = normalizeDigits(input.trim()).replaceAll('٫', '.').replaceAll(',', '.');
    var negative = false;
    if (s.startsWith('-')) {
      if (!allowNegative) return null;
      negative = true;
      s = s.substring(1);
    }
    if (!RegExp(r'^\d+(\.\d{0,3})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final frac =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1].padRight(3, '0') : '000';
    if (!unit.allowsDecimals && int.parse(frac) != 0) return null;
    final v = int.parse(parts[0]) * scale + int.parse(frac);
    return Quantity(negative ? -v : v);
  }

  bool get isZero => milli == 0;
  bool get isNegative => milli < 0;
  bool get isWhole => milli % scale == 0;
  double get value => milli / scale;

  Quantity operator +(Quantity o) => Quantity(milli + o.milli);
  Quantity operator -(Quantity o) => Quantity(milli - o.milli);
  Quantity operator -() => Quantity(-milli);

  /// `2`, `2.5`, `0.125` — Latin digits, no trailing zeros.
  String toDecimalString() {
    final sign = milli < 0 ? '-' : '';
    final abs = milli.abs();
    final whole = abs ~/ scale;
    final frac = abs % scale;
    if (frac == 0) return '$sign$whole';
    final f = frac.toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
    return '$sign$whole.$f';
  }

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);
  bool operator <(Quantity o) => milli < o.milli;
  bool operator >(Quantity o) => milli > o.milli;
  bool operator <=(Quantity o) => milli <= o.milli;
  bool operator >=(Quantity o) => milli >= o.milli;

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;
  @override
  int get hashCode => milli.hashCode;
  @override
  String toString() => 'Quantity(${toDecimalString()})';
}
