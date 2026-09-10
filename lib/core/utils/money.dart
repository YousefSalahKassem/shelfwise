import 'package:meta/meta.dart';

import 'quantity.dart';

/// Rounding step for prices, in minor units (EGP/SAR have 2 decimals).
enum RoundingStep {
  none(1),
  fiveHundredths(5),
  quarter(25),
  half(50),
  whole(100);

  const RoundingStep(this.minorStep);
  final int minorStep;
}

enum RoundingMode { nearest, up, down }

/// An amount of money stored as integer minor units (e.g. piastres, halalas).
/// Never use doubles for money in ShelfWise.
@immutable
class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);
  const Money.zero(this.currency) : minor = 0;

  final int minor;

  /// ISO 4217 code, e.g. `EGP`, `SAR`.
  final String currency;

  static const int scale = 100;

  /// Parses user input such as `12.5`, `12,50` or `١٢٫٥` into minor units.
  /// Returns null if the text is not a valid non-negative amount.
  static Money? tryParse(String input, String currency) {
    var s = normalizeDigits(input.trim()).replaceAll(' ', '');
    s = s.replaceAll('٫', '.').replaceAll(',', '.');
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(s)) return null;
    final parts = s.split('.');
    final whole = int.parse(parts[0]);
    final frac =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1].padRight(2, '0') : '00';
    return Money(whole * scale + int.parse(frac), currency);
  }

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  Money operator +(Money other) => Money(minor + _same(other).minor, currency);
  Money operator -(Money other) => Money(minor - _same(other).minor, currency);
  Money operator -() => Money(-minor, currency);

  /// Adds [percent] percent (negative to decrease), rounded to the nearest minor unit.
  Money applyPercent(double percent) =>
      Money(minor + (minor * percent / 100).round(), currency);

  /// Money × quantity (e.g. stock value), rounded to the nearest minor unit.
  Money times(Quantity quantity) =>
      Money((minor * quantity.milli / Quantity.scale).round(), currency);

  Money roundTo(RoundingStep step, {RoundingMode mode = RoundingMode.nearest}) {
    final s = step.minorStep;
    if (s == 1) return this;
    final r = minor % s;
    if (r == 0) return this;
    final down = minor - r;
    final up = down + s;
    return Money(
      switch (mode) {
        RoundingMode.down => down,
        RoundingMode.up => up,
        RoundingMode.nearest => r * 2 >= s ? up : down,
      },
      currency,
    );
  }

  /// Gross margin as a percentage of price: (price − cost) / price × 100.
  /// Returns null when the price is zero.
  static double? marginPercent({required Money price, required Money cost}) {
    if (price.minor == 0) return null;
    return (price.minor - price._same(cost).minor) * 100 / price.minor;
  }

  /// Plain decimal string with 2 fraction digits and Latin digits, e.g. `12.50`.
  String toDecimalString() {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    return '$sign${abs ~/ scale}.${(abs % scale).toString().padLeft(2, '0')}';
  }

  Money _same(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
    return other;
  }

  @override
  int compareTo(Money other) => minor.compareTo(_same(other).minor);
  bool operator <(Money other) => compareTo(other) < 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;
  @override
  int get hashCode => Object.hash(minor, currency);
  @override
  String toString() => '${toDecimalString()} $currency';
}

/// Converts Arabic-Indic (٠-٩) and Eastern Arabic-Indic (۰-۹) digits to Latin.
String normalizeDigits(String input) {
  final b = StringBuffer();
  for (final c in input.runes) {
    if (c >= 0x0660 && c <= 0x0669) {
      b.writeCharCode(0x30 + c - 0x0660);
    } else if (c >= 0x06F0 && c <= 0x06F9) {
      b.writeCharCode(0x30 + c - 0x06F0);
    } else {
      b.writeCharCode(c);
    }
  }
  return b.toString();
}
