import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/platform/fakes.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/core/utils/quantity.dart';
import 'package:shelfwise/features/stock/data/datasources/stock_local_data_source.dart';
import 'package:shelfwise/features/stock/data/repositories/stock_repository_impl.dart';
import 'package:shelfwise/features/stock/domain/entities/stock.dart';
import 'package:shelfwise/features/stock/domain/usecases/record_stock_movement.dart';
import 'package:shelfwise/features/stock/domain/usecases/set_reorder_point.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DbChanges changes;
  late FixedClock clock;
  late StockRepositoryImpl repository;
  late FakeNotificationService notifications;
  late RecordingAnalyticsService analytics;
  late SessionState session;

  late RecordStockMovement record;
  late SetReorderPoint setReorderPoint;

  /// Current cached level of a product at the seeded branch.
  Future<int> levelOf(String productId) async {
    final rows = await db.db.query(
      T.stockLevels,
      where: '${C.productId} = ? AND ${C.branchId} = ?',
      whereArgs: [productId, FakeSession.branch.id],
    );
    return rows.isEmpty ? 0 : rows.first['qty_milli']! as int;
  }

  Future<List<Map<String, Object?>>> alertsOf(String productId) => db.db.query(
        T.stockAlerts,
        where: '${C.productId} = ?',
        whereArgs: [productId],
        orderBy: 'triggered_at ASC, rowid ASC',
      );

  Future<Map<String, Object?>?> openAlertOf(String productId) async {
    final rows = await db.db.query(
      T.stockAlerts,
      where: '${C.productId} = ? AND resolved_at IS NULL',
      whereArgs: [productId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  setUp(() async {
    db = await openTestDatabase();
    await Fixtures.seed(db);
    changes = DbChanges();
    clock = FixedClock(Fixtures.now);
    notifications = FakeNotificationService();
    analytics = RecordingAnalyticsService();
    session = FakeSession.ownerSession;
    repository = StockRepositoryImpl(
      local: StockLocalDataSource(db, clock, SequentialIdGenerator('sw')),
      changes: changes,
      session: () => session,
    );
    record = RecordStockMovement(
      recorder: repository,
      session: () => session,
      notifications: notifications,
      analytics: analytics,
    );
    setReorderPoint = SetReorderPoint(
      recorder: repository,
      session: () => session,
      analytics: analytics,
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  group('the low-stock story from the brief', () {
    test('reorder point 3 · receive 10 · sell 8 → low · sell 2 → out · receive 5 → clear',
        () async {
      const product = 'prod-20'; // seeded with no stock
      expect(await setReorderPoint(product, const Quantity.whole(3)), isA<Object>());

      await record(const MovementInput(
        productId: product,
        type: MovementType.receive,
        quantity: Quantity.whole(10),
      ));
      expect(await levelOf(product), 10000);
      expect(await openAlertOf(product), isNull);
      expect(notifications.shown, isEmpty);

      clock.advance(const Duration(minutes: 1));
      await record(const MovementInput(
        productId: product,
        type: MovementType.sale,
        quantity: Quantity.whole(8),
      ));
      expect(await levelOf(product), 2000);
      expect((await openAlertOf(product))!['level'], 'low');
      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.level, StockStatus.low);

      // Selling again while still low must not notify a second time.
      clock.advance(const Duration(minutes: 1));
      await record(const MovementInput(
        productId: product,
        type: MovementType.sale,
        quantity: Quantity(500),
      ));
      expect((await openAlertOf(product))!['level'], 'low');
      expect(notifications.shown, hasLength(1));

      clock.advance(const Duration(minutes: 1));
      await record(const MovementInput(
        productId: product,
        type: MovementType.sale,
        quantity: Quantity(1500),
      ));
      expect(await levelOf(product), 0);
      expect((await openAlertOf(product))!['level'], 'out');
      expect(notifications.shown, hasLength(2));
      expect(notifications.shown.last.level, StockStatus.out);

      clock.advance(const Duration(minutes: 1));
      await record(const MovementInput(
        productId: product,
        type: MovementType.receive,
        quantity: Quantity.whole(5),
      ));
      expect(await levelOf(product), 5000);
      expect(await openAlertOf(product), isNull);
      // out (opened by the reorder point on an empty shelf) → low → out.
      final history = await alertsOf(product);
      expect(history, hasLength(3));
      expect(history.every((a) => a['resolved_at'] != null), isTrue);
      expect(notifications.shown, hasLength(2));
    });

    test('coming back from out to low keeps one alert and stays quiet', () async {
      const product = 'prod-20';
      await setReorderPoint(product, const Quantity.whole(5));
      await record(const MovementInput(
        productId: product,
        type: MovementType.receive,
        quantity: Quantity.whole(2),
      ));
      // Was already at zero, so the reorder point opened an `out` alert; the
      // delivery leaves it below the reorder point.
      final alert = await openAlertOf(product);
      expect(alert!['level'], 'low');
      expect(await alertsOf(product), hasLength(1));
      expect(notifications.shown, isEmpty);
    });
  });

  group('the ledger and the cached level agree', () {
    test('over a random sequence of movements', () async {
      const product = 'prod-1';
      final random = Random(42);
      const types = [
        MovementType.receive,
        MovementType.sale,
        MovementType.damaged,
        MovementType.expired,
        MovementType.adjustment,
      ];

      for (var i = 0; i < 60; i++) {
        clock.advance(const Duration(seconds: 30));
        final type = types[random.nextInt(types.length)];
        final magnitude = Quantity(random.nextInt(3000) + 1);
        final input = MovementInput(
          productId: product,
          type: type,
          quantity: type == MovementType.adjustment && random.nextBool()
              ? -magnitude
              : magnitude,
        );
        final before = await levelOf(product);
        final result = await record(input);
        final delta = RecordStockMovement.deltaOf(input).milli;
        if (before + delta < 0 && type != MovementType.adjustment) {
          // Rejected: stock may not go negative without a correction.
          expect(result.failureOrNull, isA<ValidationFailure>());
          expect(await levelOf(product), before);
        } else {
          expect(result.isSuccess, isTrue, reason: '$type $magnitude');
          expect(await levelOf(product), before + delta);
        }
      }

      final sum = await db.db.rawQuery(
        'SELECT SUM(qty_delta_milli) AS total FROM ${T.stockMovements} WHERE product_id = ?',
        [product],
      );
      // 20 pieces were seeded straight into stock_levels before any movement.
      expect((sum.first['total']! as int) + 20000, await levelOf(product));

      final rows = await db.db.query(
        T.stockMovements,
        where: '${C.productId} = ?',
        whereArgs: [product],
        orderBy: 'created_at ASC, rowid ASC',
      );
      var running = 20000;
      for (final row in rows) {
        running += row['qty_delta_milli']! as int;
        expect(row['qty_after_milli'], running);
      }
    });
  });

  group('one transaction', () {
    test('a failing line rolls the whole batch back', () async {
      final before = await levelOf('prod-1');
      final result = await record.many(const [
        MovementInput(
          productId: 'prod-1',
          type: MovementType.receive,
          quantity: Quantity.whole(5),
        ),
        MovementInput(
          productId: 'does-not-exist',
          type: MovementType.receive,
          quantity: Quantity.whole(5),
        ),
      ]);

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(await levelOf('prod-1'), before);
      final rows = await db.db.query(T.stockMovements);
      expect(rows, isEmpty);
      expect(notifications.shown, isEmpty);
    });

    test('a sale that would go negative is refused, an adjustment is not', () async {
      final sale = await record(const MovementInput(
        productId: 'prod-1',
        type: MovementType.sale,
        quantity: Quantity.whole(21),
      ));
      expect((sale.failureOrNull! as ValidationFailure).code, 'negativeStock');
      expect(await levelOf('prod-1'), 20000);

      final correction = await record(const MovementInput(
        productId: 'prod-1',
        type: MovementType.adjustment,
        quantity: Quantity.whole(-21),
      ));
      expect(correction.isSuccess, isTrue);
      expect(await levelOf('prod-1'), -1000);
      expect((await openAlertOf('prod-1'))!['level'], 'out');
    });

    test('a delivery of several lines is one commit and one running total',
        () async {
      final result = await record.many(const [
        MovementInput(
          productId: 'prod-2',
          type: MovementType.receive,
          quantity: Quantity.whole(3),
        ),
        MovementInput(
          productId: 'prod-2',
          type: MovementType.receive,
          quantity: Quantity.whole(4),
          unitCost: Money(1250, 'EGP'),
        ),
        MovementInput(
          productId: 'prod-3',
          type: MovementType.receive,
          quantity: Quantity.whole(1),
        ),
      ]);

      final batch = result.valueOrNull!;
      expect(batch.movements, hasLength(3));
      expect(batch.movements[1].quantityAfter, const Quantity.whole(27));
      expect(batch.movements[1].unitCost, const Money(1250, 'EGP'));
      expect(await levelOf('prod-2'), 27000);
      expect(await levelOf('prod-3'), 21000);
    });
  });

  group('reorder points', () {
    test('raising one above the current quantity opens an alert, lowering it clears',
        () async {
      expect(await levelOf('prod-1'), 20000);
      await setReorderPoint('prod-1', const Quantity.whole(25));
      expect((await openAlertOf('prod-1'))!['level'], 'low');
      // Never a notification: a bulk change would flood the store.
      expect(notifications.shown, isEmpty);

      await setReorderPoint('prod-1', const Quantity.whole(5));
      expect(await openAlertOf('prod-1'), isNull);
    });

    test('a category updates its products and, on request, its subcategories',
        () async {
      final dairyOnly = await setReorderPoint.forCategory(
        'cat-dairy',
        const Quantity.whole(2),
        includeSubcategories: false,
      );
      expect(dairyOnly.valueOrNull, 6);

      final withCheese = await setReorderPoint.forCategory(
        'cat-dairy',
        const Quantity.whole(4),
      );
      expect(withCheese.valueOrNull, 13);

      final rows = await db.db.rawQuery(
        'SELECT reorder_point_milli AS r FROM ${T.products} WHERE category_id = ?',
        ['cat-cheese'],
      );
      expect(rows.every((r) => r['r'] == 4000), isTrue);
      expect(
        analytics.events.where((e) => e.$1 == AppEvent.reorderPointSet),
        hasLength(2),
      );
    });

    test('only the owner may set them', () async {
      session = FakeSession.staffSession;
      final result = await setReorderPoint('prod-1', const Quantity.whole(9));
      expect(result.failureOrNull, isA<PermissionFailure>());
    });
  });

  group('reads', () {
    test('finds a product by barcode or SKU, newest movements first', () async {
      final byBarcode = await repository.findByCode('6220000000001');
      expect(byBarcode.valueOrNull!.productId, 'prod-1');
      final bySku = await repository.findByCode('SKU-2');
      expect(bySku.valueOrNull!.productId, 'prod-2');
      expect((await repository.findByCode('nope')).valueOrNull, isNull);

      await record(const MovementInput(
        productId: 'prod-1',
        type: MovementType.receive,
        quantity: Quantity.whole(1),
      ));
      clock.advance(const Duration(hours: 1));
      await record(const MovementInput(
        productId: 'prod-1',
        type: MovementType.damaged,
        quantity: Quantity.whole(2),
      ));

      final history = (await repository.movementEntries('prod-1')).valueOrNull!;
      expect(history.map((e) => e.movement.type),
          [MovementType.damaged, MovementType.receive]);
      expect(history.first.productName, 'Product 1');
      expect(history.first.movement.profileName, FakeSession.owner.name);
    });

    test('watchLevel re-reads after a movement', () async {
      final levels = <int>[];
      final sub = repository.watchLevel('prod-1').listen((l) => levels.add(l.quantity.milli));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await record(const MovementInput(
        productId: 'prod-1',
        type: MovementType.receive,
        quantity: Quantity.whole(5),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(levels, [20000, 25000]);
    });
  });
}
