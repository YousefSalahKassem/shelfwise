import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/utils/formatters.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/core/utils/quantity.dart';

void main() {
  test('English money', () {
    const f = AppFormatters(languageCode: 'en', latinDigits: true);
    expect(f.money(const Money(123456, 'EGP')), 'EGP 1,234.56');
  });

  test('Arabic money with Arabic-Indic digits', () {
    const f = AppFormatters(languageCode: 'ar', latinDigits: false);
    expect(f.money(const Money(1250, 'SAR')), '١٢٫٥٠ ر.س');
    expect(f.quantity(const Quantity(2500)), '٢٫٥');
  });

  test('Arabic money with Latin digits', () {
    const f = AppFormatters(languageCode: 'ar', latinDigits: true);
    expect(f.money(const Money(1250, 'EGP')), '12.50 ج.م');
  });
}
