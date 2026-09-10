import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/utils/quantity.dart';

void main() {
  test('parses whole and decimal quantities by unit', () {
    expect(Quantity.tryParse('3'), const Quantity(3000));
    expect(Quantity.tryParse('2.5', unit: ProductUnit.kg), const Quantity(2500));
    expect(Quantity.tryParse('٢٫٥', unit: ProductUnit.kg), const Quantity(2500));
    expect(Quantity.tryParse('2.5'), isNull, reason: 'pieces are whole');
    expect(Quantity.tryParse('-2'), isNull);
    expect(Quantity.tryParse('-2', allowNegative: true), const Quantity(-2000));
  });

  test('toDecimalString trims zeros', () {
    expect(const Quantity(2500).toDecimalString(), '2.5');
    expect(const Quantity(125).toDecimalString(), '0.125');
    expect(const Quantity(4000).toDecimalString(), '4');
  });

  test('StockStatus thresholds', () {
    expect(StockStatus.of(qtyMilli: 0, reorderPointMilli: 5000), StockStatus.out);
    expect(StockStatus.of(qtyMilli: 5000, reorderPointMilli: 5000), StockStatus.low);
    expect(StockStatus.of(qtyMilli: 5001, reorderPointMilli: 5000), StockStatus.ok);
    expect(StockStatus.of(qtyMilli: 1, reorderPointMilli: 0), StockStatus.ok);
  });
}
