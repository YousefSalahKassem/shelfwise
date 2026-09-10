import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/features/pricing/data/datasources/pricing_local_data_source.dart';
import 'package:shelfwise/features/pricing/data/repositories/pricing_repository_impl.dart';
import 'package:shelfwise/features/pricing/domain/entities/pricing.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DbChanges changes;
  late PricingRepositoryImpl repository;

  PricingRepositoryImpl repositoryFor(SessionState session) => PricingRepositoryImpl(
        local: PricingLocalDataSource(db),
        session: session,
        clock: FixedClock(Fixtures.now),
        ids: SequentialIdGenerator(),
        changes: changes,
      );

  setUp(() async {
    db = await openTestDatabase();
    await Fixtures.seed(db);
    changes = DbChanges();
    repository = repositoryFor(FakeSession.ownerSession);
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  Future<Map<String, Object?>> product(String id) async =>
      (await db.db.query(T.products, where: 'id = ?', whereArgs: [id])).single;

  Future<List<Map<String, Object?>>> priceChanges() =>
      db.db.query(T.priceChanges, orderBy: 'id');

  const dairyRule = BulkPriceRule(
    categoryId: 'cat-dairy',
    adjustment: PriceAdjustment.percent(10),
    rounding: RoundingStep.quarter,
  );

  group('previewBulk', () {
    test('a category includes its sub-categories by default', () async {
      final previews = (await repository.previewBulk(dairyRule)).valueOrNull!;
      // Fixtures: products are spread over Dairy › Cheese and Drinks.
      expect(previews, isNotEmpty);
      expect(previews.every((p) => p.productName.startsWith('Product')), isTrue);

      final direct = (await repository.previewBulk(
        dairyRule.copyWith(includeSubcategories: false),
      ))
          .valueOrNull!;
      expect(direct.length, lessThan(previews.length));
    });

    test('computes new prices without writing anything', () async {
      final before = await product('prod-3');
      final previews = (await repository.previewBulk(dairyRule)).valueOrNull!;
      final p = previews.firstWhere((p) => p.productId == 'prod-3');

      expect(p.oldPrice, Money(before['price_minor']! as int, 'EGP'));
      expect(p.newPrice.minor % RoundingStep.quarter.minorStep, 0);
      expect(await product('prod-3'), before, reason: 'preview must not write');
      expect(await priceChanges(), isEmpty);
    });

    test('an explicit selection wins over the category', () async {
      final previews = (await repository.previewBulk(
        const BulkPriceRule(
          categoryId: 'cat-dairy',
          productIds: ['prod-2', 'prod-5'],
          adjustment: PriceAdjustment.percent(10),
        ),
      ))
          .valueOrNull!;
      expect(previews.map((p) => p.productId).toSet(), {'prod-2', 'prod-5'});
    });

    test('flags a price that falls below cost or to zero', () async {
      final previews = (await repository.previewBulk(
        const BulkPriceRule(
          categoryId: 'cat-drinks',
          adjustment: PriceAdjustment.percent(-100),
        ),
      ))
          .valueOrNull!;
      expect(previews.every((p) => p.isZero), isTrue);
      expect(previews.every((p) => p.belowCost), isTrue);
    });
  });

  group('applyBulk', () {
    test('updates the products and writes one price_changes row each, sharing a batch id',
        () async {
      final previews = (await repository.previewBulk(dairyRule)).valueOrNull!;
      final batchId = (await repository.applyBulk(dairyRule)).valueOrNull!;

      final rows = await priceChanges();
      expect(rows.length, previews.length);
      expect(rows.map((r) => r['batch_id']).toSet(), {batchId});
      expect(rows.map((r) => r['profile_id']).toSet(), {FakeSession.owner.id});

      for (final preview in previews) {
        final updated = await product(preview.productId);
        expect(updated['price_minor'], preview.newPrice.minor, reason: preview.productId);
        expect(updated['updated_at'], Fixtures.nowMs);
      }
    });

    test('price_changes records the old and new price, and cost only when it changed',
        () async {
      await repository.applyBulk(dairyRule);
      final row = (await priceChanges()).first;
      expect(row['old_price_minor'], isNot(row['new_price_minor']));
      expect(row['old_cost_minor'], isNull, reason: 'the cost target was not selected');

      final batchId = (await repository.applyBulk(
        dairyRule.copyWith(target: PriceTarget.both),
      ))
          .valueOrNull!;
      final withCost = (await repository.batch(batchId)).valueOrNull!;
      expect(withCost.every((c) => c.oldCost != null && c.newCost != null), isTrue);
    });

    test('leaves products alone when a rule would not change them', () async {
      final result = await repository.applyBulk(
        const BulkPriceRule(
          categoryId: 'cat-drinks',
          adjustment: PriceAdjustment.percent(0),
        ),
      );
      expect((result.failureOrNull! as ValidationFailure).code, 'no_changes');
      expect(await priceChanges(), isEmpty);
    });

    test('notifies products and price_changes once the transaction commits', () async {
      final touched = changes.watch({DbTable.products, DbTable.priceChanges}).first;
      await repository.applyBulk(dairyRule);
      expect(await touched, contains(DbTable.products));
    });

    test('a failure mid-batch leaves the database untouched', () async {
      // The 3rd write will try to insert a price_changes row with id `id-4`
      // (id-1 is the batch id) — the row below already owns that id.
      await db.db.insert(T.priceChanges, {
        'id': 'id-4',
        'product_id': 'prod-1',
        'old_price_minor': 1,
        'new_price_minor': 1,
        'profile_id': FakeSession.owner.id,
        'created_at': Fixtures.nowMs,
        'updated_at': Fixtures.nowMs,
      });
      final before = await db.db.query(T.products, orderBy: 'id');

      final result = await repository.applyBulk(dairyRule);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(await db.db.query(T.products, orderBy: 'id'), before,
          reason: 'no product may keep a new price');
      expect((await priceChanges()).length, 1, reason: 'only the pre-existing row');
    });

    test('a staff session cannot be smuggled past the repository through the use case',
        () async {
      // The repository itself trusts its caller; the guard is the use case
      // (see pricing_usecases_test.dart). What it must do is scope by store.
      final other = repositoryFor(
        const SessionState(
          store: Store(id: 'other-store', name: 'X', currency: 'EGP', locale: 'en'),
          branch: FakeSession.branch,
          profile: FakeSession.owner,
        ),
      );
      final result = await other.applyBulk(dairyRule);
      expect((result.failureOrNull! as ValidationFailure).code, 'no_changes');
      expect(await priceChanges(), isEmpty);
    });
  });

  group('updatePrice', () {
    test('writes the new price, the new cost and one history row', () async {
      final result = await repository.updatePrice(
        'prod-1',
        price: const Money(2500, 'EGP'),
        cost: const Money(1200, 'EGP'),
      );
      expect(result.isSuccess, isTrue);

      final row = await product('prod-1');
      expect(row['price_minor'], 2500);
      expect(row['cost_minor'], 1200);

      final change = (await priceChanges()).single;
      expect(change['batch_id'], isNull, reason: 'single edits are not a batch');
      expect(change['new_price_minor'], 2500);
      expect(change['old_cost_minor'], 1010);
      expect(change['new_cost_minor'], 1200);
    });

    test('keeps the current cost when none is given', () async {
      await repository.updatePrice('prod-2', price: const Money(2500, 'EGP'));
      final row = await product('prod-2');
      expect(row['cost_minor'], 1020);
      expect((await priceChanges()).single['new_cost_minor'], isNull);
    });

    test('an unchanged price writes no history row', () async {
      final current = await product('prod-1');
      final result = await repository.updatePrice(
        'prod-1',
        price: Money(current['price_minor']! as int, 'EGP'),
      );
      expect(result.isSuccess, isTrue);
      expect(await priceChanges(), isEmpty);
    });

    test('an unknown product is a NotFoundFailure', () async {
      final result = await repository.updatePrice('nope', price: const Money(100, 'EGP'));
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('an archived product is out of scope', () async {
      await db.db.update(T.products, {'is_archived': 1}, where: 'id = ?', whereArgs: ['prod-4']);
      final result = await repository.updatePrice('prod-4', price: const Money(100, 'EGP'));
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('history and batch', () {
    test('history is newest first and batch returns the whole group', () async {
      await repository.updatePrice('prod-1', price: const Money(2000, 'EGP'));
      final batchId = (await repository.applyBulk(
        const BulkPriceRule(
          productIds: ['prod-1'],
          adjustment: PriceAdjustment.percent(10),
        ),
      ))
          .valueOrNull!;

      final history = (await repository.history('prod-1')).valueOrNull!;
      expect(history.length, 2);
      expect(history.first.batchId, batchId);
      expect(history.first.newPrice, const Money(2200, 'EGP'));

      final batch = (await repository.batch(batchId)).valueOrNull!;
      expect(batch.single.productId, 'prod-1');
    });
  });

  group('performance (200 products, business-plan §9 target)', () {
    setUp(() async {
      final now = Fixtures.nowMs;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (var i = 100; i < 300; i++) {
          batch.insert(T.products, {
            'id': 'perf-$i',
            'store_id': FakeSession.store.id,
            'category_id': 'cat-drinks',
            'name': 'Perf $i',
            'unit': 'piece',
            'cost_minor': 500 + i,
            'price_minor': 1000 + i,
            'reorder_point_milli': 0,
            'created_at': now,
            'updated_at': now,
          });
        }
        await batch.commit(noResult: true);
      });
    });

    test('preview under 1 s and apply under 2 s', () async {
      const rule = BulkPriceRule(
        categoryId: 'cat-drinks',
        includeSubcategories: false,
        adjustment: PriceAdjustment.percent(10),
        rounding: RoundingStep.quarter,
      );

      final previewStart = DateTime.now();
      final previews = (await repository.previewBulk(rule)).valueOrNull!;
      final previewMs = DateTime.now().difference(previewStart).inMilliseconds;

      final applyStart = DateTime.now();
      final batchId = (await repository.applyBulk(rule)).valueOrNull!;
      final applyMs = DateTime.now().difference(applyStart).inMilliseconds;

      expect(previews.length, greaterThanOrEqualTo(200));
      expect((await repository.batch(batchId)).valueOrNull!.length, previews.length);
      expect(previewMs, lessThan(1000), reason: 'preview took ${previewMs}ms');
      expect(applyMs, lessThan(2000), reason: 'apply took ${applyMs}ms');
    });
  });
}
