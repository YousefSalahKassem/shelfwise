import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/domain/stock_status.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/platform/fakes.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/utils/date_range.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/core/utils/quantity.dart';
import 'package:shelfwise/features/stock/domain/entities/stock.dart';
import 'package:shelfwise/features/stock/domain/entities/stock_view.dart';
import 'package:shelfwise/features/stock/domain/repositories/stock_recorder.dart';
import 'package:shelfwise/features/stock/domain/usecases/record_stock_movement.dart';

/// Records what it was asked to write and returns whatever the test set up.
class _FakeRecorder implements StockRecorder {
  List<MovementInput> received = const [];
  MovementBatch next = const MovementBatch();
  Failure? failure;

  @override
  Future<Result<MovementBatch>> recordBatch(List<MovementInput> inputs) async {
    received = inputs;
    return failure == null ? Success(next) : Err(failure!);
  }

  @override
  Future<Result<StockMovement>> record(MovementInput input) async =>
      (await recordBatch([input])).map((b) => b.movements.first);

  @override
  Future<Result<List<StockMovement>>> recordMany(List<MovementInput> inputs) async =>
      (await recordBatch(inputs)).map((b) => b.movements);

  @override
  Future<Result<void>> setReorderPoint(String productId, Quantity reorderPoint) async => ok;

  @override
  Future<Result<int>> setReorderPointForCategory(String categoryId, Quantity reorderPoint,
          {bool includeSubcategories = true}) async =>
      const Success(0);

  @override
  Stream<StockLevel> watchLevel(String productId) => const Stream.empty();

  @override
  Future<Result<ProductStock>> productStock(String productId) async =>
      const Err(NotFoundFailure('product'));

  @override
  Future<Result<ProductStock?>> findByCode(String code) async => const Success(null);

  @override
  Future<Result<List<MovementEntry>>> recentMovements({int limit = 20}) async =>
      const Success([]);

  @override
  Future<Result<List<MovementEntry>>> movementEntries(String productId,
          {DateRange? range, int limit = 100}) async =>
      const Success([]);

  @override
  Future<Result<List<StockMovement>>> movements(String productId,
          {DateRange? range, int limit = 100}) async =>
      const Success([]);
}

StockMovement _movement({
  MovementType type = MovementType.receive,
  int deltaMilli = 10000,
  int afterMilli = 10000,
}) =>
    StockMovement(
      id: 'mov-1',
      productId: 'prod-1',
      branchId: 'branch-1',
      type: type,
      delta: Quantity(deltaMilli),
      quantityAfter: Quantity(afterMilli),
      profileId: 'profile-owner',
      createdAt: DateTime.utc(2026, 9, 1),
    );

void main() {
  late _FakeRecorder recorder;
  late FakeNotificationService notifications;
  late RecordingAnalyticsService analytics;

  RecordStockMovement useCase([SessionState session = FakeSession.ownerSession]) =>
      RecordStockMovement(
        recorder: recorder,
        session: () => session,
        notifications: notifications,
        analytics: analytics,
        quantityLabel: (q, unit) => '${q.toDecimalString()} ${unit.name}',
      );

  setUp(() {
    recorder = _FakeRecorder();
    notifications = FakeNotificationService();
    analytics = RecordingAnalyticsService();
  });

  const receiveTen = MovementInput(
    productId: 'prod-1',
    type: MovementType.receive,
    quantity: Quantity.whole(10),
  );

  group('permissions', () {
    test('staff may receive and adjust stock', () async {
      recorder.next = MovementBatch(movements: [_movement()]);
      final result = await useCase(FakeSession.staffSession)(receiveTen);
      expect(result.isSuccess, isTrue);

      recorder.next = MovementBatch(movements: [_movement(type: MovementType.adjustment)]);
      final adjusted = await useCase(FakeSession.staffSession)(
        const MovementInput(
          productId: 'prod-1',
          type: MovementType.adjustment,
          quantity: Quantity(-2000),
        ),
      );
      expect(adjusted.isSuccess, isTrue);
    });

    test('a locked session writes nothing', () async {
      final result = await useCase(FakeSession.locked)(receiveTen);
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(recorder.received, isEmpty);
    });
  });

  group('validation', () {
    test('rejects a zero quantity', () async {
      final result = await useCase()(
        const MovementInput(
          productId: 'prod-1',
          type: MovementType.receive,
          quantity: Quantity.zero(),
        ),
      );
      expect((result.failureOrNull! as ValidationFailure).code, 'required');
      expect(recorder.received, isEmpty);
    });

    test('typed movements carry a magnitude, not a sign', () async {
      final result = await useCase()(
        const MovementInput(
          productId: 'prod-1',
          type: MovementType.sale,
          quantity: Quantity(-1000),
        ),
      );
      expect((result.failureOrNull! as ValidationFailure).code, 'mustBePositive');
    });

    test('rejects a negative unit cost and an over-long note', () async {
      final costly = await useCase()(
        MovementInput(
          productId: 'prod-1',
          type: MovementType.receive,
          quantity: const Quantity.whole(1),
          unitCost: const Money(-500, 'EGP'),
        ),
      );
      expect((costly.failureOrNull! as ValidationFailure).field, 'unitCost');

      final chatty = await useCase()(
        MovementInput(
          productId: 'prod-1',
          type: MovementType.receive,
          quantity: const Quantity.whole(1),
          note: 'x' * (RecordStockMovement.maxNoteLength + 1),
        ),
      );
      expect((chatty.failureOrNull! as ValidationFailure).field, 'note');
    });

    test('nothing is written when one line of a batch is invalid', () async {
      final result = await useCase().many([
        receiveTen,
        const MovementInput(
          productId: 'prod-2',
          type: MovementType.receive,
          quantity: Quantity.zero(),
        ),
      ]);
      expect(result.isSuccess, isFalse);
      expect(recorder.received, isEmpty);
    });
  });

  group('after the commit', () {
    test('notifies once per opened alert and logs the pilot events', () async {
      recorder.next = MovementBatch(
        movements: [_movement(type: MovementType.sale, deltaMilli: -8000, afterMilli: 2000)],
        openedAlerts: const [
          OpenedAlert(
            alertId: 'alert-1',
            productId: 'prod-1',
            productName: 'Milk 1L',
            level: StockStatus.low,
            quantity: Quantity.whole(2),
            reorderPoint: Quantity.whole(3),
          ),
        ],
      );

      final result = await useCase()(
        const MovementInput(
          productId: 'prod-1',
          type: MovementType.sale,
          quantity: Quantity.whole(8),
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.productName, 'Milk 1L');
      expect(notifications.shown.single.level, StockStatus.low);
      expect(notifications.shown.single.quantityText, '2 piece');
      expect(
        analytics.events.map((e) => e.$1),
        containsAll([AppEvent.stockMovementRecorded, AppEvent.lowStockAlertFired]),
      );
    });

    test('no alert means no notification', () async {
      recorder.next = MovementBatch(movements: [_movement()]);
      await useCase()(receiveTen);
      expect(notifications.shown, isEmpty);
      expect(analytics.events.map((e) => e.$1), [AppEvent.stockMovementRecorded]);
    });

    test('a failed write never notifies', () async {
      recorder.failure = const StorageFailure('disk full');
      final result = await useCase()(receiveTen);
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(notifications.shown, isEmpty);
      expect(analytics.events, isEmpty);
    });
  });
}
