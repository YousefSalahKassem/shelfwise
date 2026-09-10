import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/core/utils/quantity.dart';

void main() {
  const egp = 'EGP';

  group('Money.tryParse', () {
    test('parses dot, comma and Arabic digits', () {
      expect(Money.tryParse('12.5', egp), const Money(1250, egp));
      expect(Money.tryParse('12,50', egp), const Money(1250, egp));
      expect(Money.tryParse('١٢٫٥', egp), const Money(1250, egp));
      expect(Money.tryParse('7', egp), const Money(700, egp));
    });
    test('rejects invalid input', () {
      expect(Money.tryParse('', egp), isNull);
      expect(Money.tryParse('-1', egp), isNull);
      expect(Money.tryParse('1.234', egp), isNull);
      expect(Money.tryParse('abc', egp), isNull);
    });
  });

  test('arithmetic keeps currency and refuses mixing', () {
    expect(const Money(100, egp) + const Money(50, egp), const Money(150, egp));
    expect(() => const Money(100, egp) + const Money(1, 'SAR'), throwsArgumentError);
  });

  test('applyPercent rounds to nearest minor unit', () {
    expect(const Money(1999, egp).applyPercent(10), const Money(2199, egp)); // 199.9 → 200
    expect(const Money(1000, egp).applyPercent(-5), const Money(950, egp));
  });

  group('roundTo', () {
    test('quarter nearest/up/down', () {
      expect(const Money(1212, egp).roundTo(RoundingStep.quarter), const Money(1200, egp));
      expect(const Money(1213, egp).roundTo(RoundingStep.quarter), const Money(1225, egp));
      expect(const Money(1201, egp).roundTo(RoundingStep.quarter, mode: RoundingMode.up), const Money(1225, egp));
      expect(const Money(1249, egp).roundTo(RoundingStep.quarter, mode: RoundingMode.down), const Money(1225, egp));
    });
    test('exact multiples and none are unchanged', () {
      expect(const Money(1250, egp).roundTo(RoundingStep.half), const Money(1250, egp));
      expect(const Money(1237, egp).roundTo(RoundingStep.none), const Money(1237, egp));
    });
    test('whole pound', () {
      expect(const Money(1250, egp).roundTo(RoundingStep.whole), const Money(1300, egp));
      expect(const Money(1249, egp).roundTo(RoundingStep.whole), const Money(1200, egp));
    });
  });

  test('marginPercent', () {
    expect(Money.marginPercent(price: const Money(2000, egp), cost: const Money(1500, egp)), 25);
    expect(Money.marginPercent(price: const Money(0, egp), cost: const Money(1, egp)), isNull);
  });

  test('times quantity', () {
    expect(const Money(1000, egp).times(const Quantity(2500)), const Money(2500, egp));
  });

  test('toDecimalString', () {
    expect(const Money(5, egp).toDecimalString(), '0.05');
    expect(const Money(-1250, egp).toDecimalString(), '-12.50');
  });
}
