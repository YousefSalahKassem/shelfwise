import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/pricing.dart';
import '../../domain/repositories/pricing_repository.dart';
import '../../domain/services/price_calculator.dart';
import '../datasources/pricing_local_data_source.dart';
import '../mappers/price_change_mapper.dart';
import '../models/pricing_rows.dart';

class PricingRepositoryImpl implements PricingRepository {
  const PricingRepositoryImpl({
    required this.local,
    required this.session,
    required this.clock,
    required this.ids,
    required this.changes,
  });

  final PricingLocalDataSource local;
  final SessionReader session;
  final Clock clock;
  final IdGenerator ids;
  final DbChanges changes;

  static const _touched = {DbTable.products, DbTable.priceChanges};

  String get _currency => session.store?.currency ?? '';

  @override
  Future<Result<void>> updatePrice(String productId, {required Money price, Money? cost}) async {
    final store = session.store;
    final profile = session.profile;
    if (store == null || profile == null) {
      return const Err<void>(NotFoundFailure('session'));
    }
    try {
      final rows = await local.productsInScope(storeId: store.id, productIds: [productId]);
      if (rows.isEmpty) return Err<void>(NotFoundFailure('product', productId));
      final row = rows.first;
      final write = PriceChangeWrite(
        productId: row.id,
        oldPriceMinor: row.priceMinor,
        newPriceMinor: price.minor,
        oldCostMinor: row.costMinor,
        newCostMinor: cost?.minor ?? row.costMinor,
      );
      if (write.isNoop) return ok;
      await local.applyChanges(
        writes: [write],
        changeIds: [ids.newId()],
        profileId: profile.id,
        nowMs: clock.now().epochMs,
      );
      changes.notify(_touched);
      return ok;
    } on Object catch (e) {
      return Err<void>(StorageFailure('pricing.updatePrice', e));
    }
  }

  @override
  Future<Result<List<PriceChangePreview>>> previewBulk(BulkPriceRule rule) async {
    final store = session.store;
    if (store == null) return const Err<List<PriceChangePreview>>(NotFoundFailure('session'));
    try {
      final rows = await _scope(rule, store.id);
      final currency = store.currency;
      return Success<List<PriceChangePreview>>([
        for (final row in rows) _preview(row, rule, currency),
      ]);
    } on Object catch (e) {
      return Err<List<PriceChangePreview>>(StorageFailure('pricing.previewBulk', e));
    }
  }

  @override
  Future<Result<String>> applyBulk(BulkPriceRule rule) async {
    final store = session.store;
    final profile = session.profile;
    if (store == null || profile == null) {
      return const Err<String>(NotFoundFailure('session'));
    }
    try {
      final rows = await _scope(rule, store.id);
      final writes = <PriceChangeWrite>[];
      for (final row in rows) {
        final next = PriceCalculator.apply(
          rule: rule,
          price: Money(row.priceMinor, store.currency),
          cost: Money(row.costMinor, store.currency),
        );
        final write = PriceChangeWrite(
          productId: row.id,
          oldPriceMinor: row.priceMinor,
          newPriceMinor: next.price.minor,
          oldCostMinor: row.costMinor,
          newCostMinor: next.cost.minor,
        );
        if (!write.isNoop) writes.add(write);
      }
      if (writes.isEmpty) {
        return const Err<String>(ValidationFailure(field: 'products', code: 'no_changes'));
      }
      final batchId = ids.newId();
      await local.applyChanges(
        writes: writes,
        changeIds: [for (var i = 0; i < writes.length; i++) ids.newId()],
        profileId: profile.id,
        nowMs: clock.now().epochMs,
        batchId: batchId,
      );
      changes.notify(_touched);
      return Success<String>(batchId);
    } on Object catch (e) {
      return Err<String>(StorageFailure('pricing.applyBulk', e));
    }
  }

  @override
  Future<Result<List<PriceChange>>> history(String productId) async {
    try {
      final rows = await local.priceChangesForProduct(productId);
      return Success<List<PriceChange>>([
        for (final row in rows) priceChangeFromRow(row, _currency),
      ]);
    } on Object catch (e) {
      return Err<List<PriceChange>>(StorageFailure('pricing.history', e));
    }
  }

  @override
  Future<Result<List<PriceChange>>> batch(String batchId) async {
    try {
      final rows = await local.priceChangesForBatch(batchId);
      return Success<List<PriceChange>>([
        for (final row in rows) priceChangeFromRow(row, _currency),
      ]);
    } on Object catch (e) {
      return Err<List<PriceChange>>(StorageFailure('pricing.batch', e));
    }
  }

  Future<List<ProductPricingRow>> _scope(BulkPriceRule rule, String storeId) =>
      local.productsInScope(
        storeId: storeId,
        categoryId: rule.categoryId,
        includeSubcategories: rule.includeSubcategories,
        productIds: rule.productIds,
      );

  PriceChangePreview _preview(ProductPricingRow row, BulkPriceRule rule, String currency) {
    final oldPrice = Money(row.priceMinor, currency);
    final oldCost = Money(row.costMinor, currency);
    final next = PriceCalculator.apply(rule: rule, price: oldPrice, cost: oldCost);
    return PriceChangePreview(
      productId: row.id,
      productName: row.name,
      oldPrice: oldPrice,
      newPrice: next.price,
      oldCost: oldCost,
      newCost: next.cost,
    );
  }
}
