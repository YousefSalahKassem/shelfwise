import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/features/pricing/domain/entities/pricing.dart';
import 'package:shelfwise/features/pricing/domain/repositories/pricing_repository.dart';
import 'package:shelfwise/features/pricing/domain/services/price_calculator.dart';

/// A product as the fake repository stores it.
class FakeProduct {
  FakeProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.costMinor,
    this.categoryId,
  });

  final String id;
  final String name;
  final String? categoryId;
  int priceMinor;
  int costMinor;
}

/// In-memory [PricingRepository] that runs the real [PriceCalculator], so use
/// case and widget tests behave like the SQL one without a database.
/// (Database behaviour itself is covered by `data/pricing_repository_test.dart`;
/// sqflite futures never complete inside a widget test's fake-async zone.)
class FakePricingRepository implements PricingRepository {
  FakePricingRepository({
    this.currency = 'EGP',
    List<FakeProduct>? products,
    this.parentOf = const {},
  }) : products = products ??
            [
              FakeProduct(
                id: 'prod-1',
                name: 'Milk 1L',
                priceMinor: 1510,
                costMinor: 1010,
                categoryId: 'cat-dairy',
              ),
              FakeProduct(
                id: 'prod-2',
                name: 'Cheese 250g',
                priceMinor: 2000,
                costMinor: 1200,
                categoryId: 'cat-cheese',
              ),
            ];

  final String currency;
  final List<FakeProduct> products;

  /// categoryId → parent, so sub-category scoping can be exercised.
  final Map<String, String?> parentOf;

  /// Method names in call order — lets a test prove nothing was touched.
  final List<String> calls = [];
  final List<PriceChange> changes = [];

  /// When set, [applyBulk] fails with it instead of writing.
  Failure? applyFailure;

  int _seq = 0;
  String _id(String prefix) => '$prefix-${++_seq}';

  List<FakeProduct> _scope(BulkPriceRule rule) => rule.productIds.isNotEmpty
      ? [
          for (final id in rule.productIds)
            ...products.where((p) => p.id == id),
        ]
      : products
          .where((p) =>
              p.categoryId == rule.categoryId ||
              (rule.includeSubcategories && parentOf[p.categoryId] == rule.categoryId))
          .toList();

  Money _money(int minor) => Money(minor, currency);

  @override
  Future<Result<List<PriceChangePreview>>> previewBulk(BulkPriceRule rule) async {
    calls.add('previewBulk');
    return Success([
      for (final p in _scope(rule))
        () {
          final next = PriceCalculator.apply(
            rule: rule,
            price: _money(p.priceMinor),
            cost: _money(p.costMinor),
          );
          return PriceChangePreview(
            productId: p.id,
            productName: p.name,
            oldPrice: _money(p.priceMinor),
            newPrice: next.price,
            oldCost: _money(p.costMinor),
            newCost: next.cost,
          );
        }(),
    ]);
  }

  @override
  Future<Result<String>> applyBulk(BulkPriceRule rule) async {
    calls.add('applyBulk');
    final failure = applyFailure;
    if (failure != null) return Err(failure);
    final scope = _scope(rule);
    final batchId = _id('batch');
    var wrote = false;
    for (final p in scope) {
      final next = PriceCalculator.apply(
        rule: rule,
        price: _money(p.priceMinor),
        cost: _money(p.costMinor),
      );
      if (next.price.minor == p.priceMinor && next.cost.minor == p.costMinor) continue;
      changes.add(_record(p, next.price, next.cost, batchId));
      p.priceMinor = next.price.minor;
      p.costMinor = next.cost.minor;
      wrote = true;
    }
    if (!wrote) {
      return const Err(ValidationFailure(field: 'products', code: 'no_changes'));
    }
    return Success(batchId);
  }

  @override
  Future<Result<void>> updatePrice(String productId, {required Money price, Money? cost}) async {
    calls.add('updatePrice($productId)');
    final match = products.where((p) => p.id == productId);
    if (match.isEmpty) return Err(NotFoundFailure('product', productId));
    final product = match.first;
    final newCost = cost ?? _money(product.costMinor);
    if (product.priceMinor == price.minor && product.costMinor == newCost.minor) return ok;
    changes.add(_record(product, price, newCost, null));
    product.priceMinor = price.minor;
    product.costMinor = newCost.minor;
    return ok;
  }

  @override
  Future<Result<List<PriceChange>>> history(String productId) async => Success(
        changes.where((c) => c.productId == productId).toList().reversed.toList(),
      );

  @override
  Future<Result<List<PriceChange>>> batch(String batchId) async =>
      Success(changes.where((c) => c.batchId == batchId).toList());

  PriceChange _record(FakeProduct product, Money price, Money cost, String? batchId) => PriceChange(
        id: _id('pc'),
        productId: product.id,
        oldPrice: _money(product.priceMinor),
        newPrice: price,
        oldCost: product.costMinor == cost.minor ? null : _money(product.costMinor),
        newCost: product.costMinor == cost.minor ? null : cost,
        batchId: batchId,
        profileId: 'profile-owner',
        createdAt: DateTime.utc(2026, 9, 1),
      );
}
