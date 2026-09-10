import 'package:intl/intl.dart';

import 'money.dart';
import 'quantity.dart';

/// Formats numbers for display. Uses Latin digits internally and converts to
/// Arabic-Indic when [latinDigits] is false and the language is Arabic, so
/// output is identical across platforms.
class AppFormatters {
  const AppFormatters({required this.languageCode, required this.latinDigits});

  final String languageCode;
  final bool latinDigits;

  static const _currencySymbols = {
    'EGP': {'en': 'EGP', 'ar': 'ج.م'},
    'SAR': {'en': 'SAR', 'ar': 'ر.س'},
  };

  bool get _arabic => languageCode == 'ar';

  String money(Money m, {bool withSymbol = true}) {
    final n = NumberFormat('#,##0.00', 'en').format(m.minor / Money.scale);
    final digits = _digits(n);
    if (!withSymbol) return digits;
    final symbol = _currencySymbols[m.currency]?[_arabic ? 'ar' : 'en'] ?? m.currency;
    return _arabic ? '$digits $symbol' : '$symbol $digits';
  }

  String quantity(Quantity q) => _digits(q.toDecimalString());

  String number(num n) => _digits(NumberFormat.decimalPattern('en').format(n));

  String percent(double p, {int decimals = 1}) =>
      '${_digits(p.toStringAsFixed(decimals))}%';

  String _digits(String s) {
    if (latinDigits || !_arabic) return s;
    final b = StringBuffer();
    for (final c in s.runes) {
      if (c >= 0x30 && c <= 0x39) {
        b.writeCharCode(0x0660 + c - 0x30);
      } else if (c == 0x2E) {
        b.write('٫');
      } else if (c == 0x2C) {
        b.write('٬');
      } else {
        b.writeCharCode(c);
      }
    }
    return b.toString();
  }
}
