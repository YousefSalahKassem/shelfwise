import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/features/pricing/domain/entities/pricing.dart';
import 'package:shelfwise/features/pricing/domain/services/price_calculator.dart';

void main() {
  const currency = 'EGP';
  Money egp(int minor) => Money(minor, currency);

  BulkPriceRule rule({
    required PriceAdjustment adjustment,
    PriceTarget target = PriceTarget.price,
    RoundingStep rounding = RoundingStep.none,
    RoundingMode mode = RoundingMode.nearest,
  }) =>
      BulkPriceRule(
        categoryId: 'cat-1',
        adjustment: adjustment,
        target: target,
        rounding: rounding,
        roundingMode: mode,
      );

  ({Money price, Money cost}) apply(BulkPriceRule r, {int price = 1000, int cost = 600}) =>
      PriceCalculator.apply(rule: r, price: egp(price), cost: egp(cost));

  group('percent', () {
    test('+10% raises the price and leaves the cost alone', () {
      final result = apply(rule(adjustment: const PriceAdjustment.percent(10)));
      expect(result.price, egp(1100));
      expect(result.cost, egp(600));
    });

    test('−15% lowers the price', () {
      expect(apply(rule(adjustment: const PriceAdjustment.percent(-15))).price, egp(850));
    });

    test('rounds to the nearest minor unit (12.35 + 7% = 13.2145 → 13.21)', () {
      expect(apply(rule(adjustment: const PriceAdjustment.percent(7)), price: 1235).price,
          egp(1321));
    });

    test('a zero price stays zero', () {
      final result = apply(rule(adjustment: const PriceAdjustment.percent(10)), price: 0);
      expect(result.price, egp(0));
    });

    test('a result below zero is blocked at zero, never negative', () {
      final result = apply(rule(adjustment: const PriceAdjustment.percent(-150)));
      expect(result.price, egp(0));
      expect(result.price.isNegative, isFalse);
    });
  });

  group('fixed amount', () {
    test('adds the amount', () {
      expect(apply(rule(adjustment: PriceAdjustment.fixed(egp(250)))).price, egp(1250));
    });

    test('subtracts a negative amount and clamps at zero', () {
      expect(apply(rule(adjustment: PriceAdjustment.fixed(egp(-2500)))).price, egp(0));
    });
  });

  group('targets', () {
    test('cost only leaves the price untouched', () {
      final result = apply(
        rule(adjustment: const PriceAdjustment.percent(10), target: PriceTarget.cost),
      );
      expect(result.price, egp(1000));
      expect(result.cost, egp(660));
    });

    test('both moves price and cost', () {
      final result = apply(
        rule(adjustment: const PriceAdjustment.percent(10), target: PriceTarget.both),
      );
      expect(result.price, egp(1100));
      expect(result.cost, egp(660));
    });

    test('cost is never rounded, even when a rounding step is set', () {
      final result = apply(
        rule(
          adjustment: const PriceAdjustment.percent(10),
          target: PriceTarget.both,
          rounding: RoundingStep.quarter,
        ),
        price: 1000,
        cost: 613,
      );
      expect(result.price, egp(1100));
      expect(result.cost, egp(674), reason: '613 + 10% = 674.3 → 674, unrounded');
    });
  });

  group('rounding', () {
    test('0.25 nearest rounds both ways', () {
      Money priceAfter(int price) => apply(
            rule(
              adjustment: const PriceAdjustment.percent(0),
              rounding: RoundingStep.quarter,
            ),
            price: price,
          ).price;
      expect(priceAfter(1010), egp(1000));
      expect(priceAfter(1013), egp(1025));
      expect(priceAfter(1088), egp(1100));
    });

    test('0.25 up always rounds away from zero', () {
      Money priceAfter(int price) => apply(
            rule(
              adjustment: const PriceAdjustment.percent(0),
              rounding: RoundingStep.quarter,
              mode: RoundingMode.up,
            ),
            price: price,
          ).price;
      expect(priceAfter(1001), egp(1025));
      expect(priceAfter(1025), egp(1025), reason: 'already on the step');
    });

    test('every step lands on a multiple of itself', () {
      for (final step in RoundingStep.values) {
        final result = apply(
          rule(
            adjustment: const PriceAdjustment.percent(10),
            rounding: step,
          ),
          price: 1237,
        );
        expect(result.price.minor % step.minorStep, 0, reason: step.name);
      }
    });

    test('+10% with 0.25 rounding: 12.35 → 13.585 → 13.50', () {
      final result = apply(
        rule(adjustment: const PriceAdjustment.percent(10), rounding: RoundingStep.quarter),
        price: 1235,
      );
      expect(result.price, egp(1350));
    });
  });

  group('adjustment helpers', () {
    test('modeName is what the pilot event logs', () {
      expect(const PriceAdjustment.percent(5).modeName, 'percent');
      expect(PriceAdjustment.fixed(egp(5)).modeName, 'fixed');
    });

    test('isNoop spots adjustments that change nothing', () {
      expect(const PriceAdjustment.percent(0).isNoop, isTrue);
      expect(PriceAdjustment.fixed(egp(0)).isNoop, isTrue);
      expect(const PriceAdjustment.percent(0.5).isNoop, isFalse);
    });
  });
}
