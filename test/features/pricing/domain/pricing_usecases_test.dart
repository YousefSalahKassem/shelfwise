import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/utils/money.dart';
import 'package:shelfwise/features/pricing/domain/entities/pricing.dart';
import 'package:shelfwise/features/pricing/domain/usecases/apply_bulk_prices.dart';
import 'package:shelfwise/features/pricing/domain/usecases/get_product_pricing.dart';
import 'package:shelfwise/features/pricing/domain/usecases/preview_bulk_prices.dart';
import 'package:shelfwise/features/pricing/domain/usecases/update_price.dart';

import '../support/fake_pricing_repository.dart';

void main() {
  const price = Money(1500, 'EGP');
  late FakePricingRepository repository;
  late RecordingAnalyticsService analytics;

  setUp(() {
    repository = FakePricingRepository(parentOf: const {'cat-cheese': 'cat-dairy'});
    analytics = RecordingAnalyticsService();
  });

  BulkPriceRule rule({PriceAdjustment adjustment = const PriceAdjustment.percent(10)}) =>
      BulkPriceRule(categoryId: 'cat-dairy', adjustment: adjustment);

  group('permissions (owner only, TECHNICAL_STRUCTURE §10)', () {
    test('staff calling UpdatePrice directly is refused', () async {
      final usecase =
          UpdatePrice(repository: repository, session: FakeSession.staffSession);
      final result = await usecase('prod-1', price: price);
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(repository.calls, isEmpty);
    });

    test('staff calling ApplyBulkPrices directly is refused and nothing is logged', () async {
      final usecase = ApplyBulkPrices(
        repository: repository,
        session: FakeSession.staffSession,
        analytics: analytics,
      );
      final result = await usecase(rule(), duration: Duration.zero);
      expect(result.failureOrNull, isA<PermissionFailure>());
      expect(repository.calls, isEmpty);
      expect(analytics.events, isEmpty);
    });

    test('staff calling PreviewBulkPrices directly is refused', () async {
      final usecase =
          PreviewBulkPrices(repository: repository, session: FakeSession.staffSession);
      expect(
        (await usecase(rule())).failureOrNull,
        isA<PermissionFailure>(),
      );
    });

    test('a locked session is refused even for an owner', () async {
      final usecase = UpdatePrice(repository: repository, session: FakeSession.locked);
      expect((await usecase('prod-1', price: price)).failureOrNull, isA<PermissionFailure>());
    });

    test('the owner is allowed through', () async {
      final usecase = UpdatePrice(repository: repository, session: FakeSession.ownerSession);
      expect((await usecase('prod-1', price: price)).isSuccess, isTrue);
      expect(repository.calls.single, contains('updatePrice(prod-1'));
    });
  });

  group('validation', () {
    test('a negative price is rejected before the repository is touched', () async {
      final usecase = UpdatePrice(repository: repository, session: FakeSession.ownerSession);
      final result = await usecase('prod-1', price: const Money(-1, 'EGP'));
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(repository.calls, isEmpty);
    });

    test('a price in another currency is rejected', () async {
      final usecase = UpdatePrice(repository: repository, session: FakeSession.ownerSession);
      final result = await usecase('prod-1', price: const Money(1500, 'SAR'));
      expect((result.failureOrNull! as ValidationFailure).code, 'currency_mismatch');
    });

    test('a rule with no category and no products is rejected', () async {
      final usecase =
          ApplyBulkPrices(repository: repository, session: FakeSession.ownerSession, analytics: analytics);
      final result = await usecase(
        const BulkPriceRule(adjustment: PriceAdjustment.percent(10)),
        duration: Duration.zero,
      );
      expect((result.failureOrNull! as ValidationFailure).field, 'scope');
    });

    test('an adjustment that changes nothing is rejected', () async {
      final usecase =
          ApplyBulkPrices(repository: repository, session: FakeSession.ownerSession, analytics: analytics);
      final result = await usecase(
        rule(adjustment: const PriceAdjustment.percent(0)),
        duration: Duration.zero,
      );
      expect((result.failureOrNull! as ValidationFailure).code, 'no_change');
    });

    test('a fixed amount in another currency is rejected', () async {
      final usecase =
          ApplyBulkPrices(repository: repository, session: FakeSession.ownerSession, analytics: analytics);
      final result = await usecase(
        rule(adjustment: const PriceAdjustment.fixed(Money(100, 'SAR'))),
        duration: Duration.zero,
      );
      expect((result.failureOrNull! as ValidationFailure).code, 'currency_mismatch');
    });

    test('preview allows a no-op rule, so the screen can show current prices', () async {
      final usecase =
          PreviewBulkPrices(repository: repository, session: FakeSession.ownerSession);
      final result = await usecase(rule(adjustment: const PriceAdjustment.percent(0)));
      expect(result.isSuccess, isTrue);
    });
  });

  group('ApplyBulkPrices', () {
    test('logs bulk_price_updated with count, duration and mode', () async {
      final usecase = ApplyBulkPrices(
        repository: repository,
        session: FakeSession.ownerSession,
        analytics: analytics,
      );
      final result = await usecase(rule(), duration: const Duration(seconds: 42));
      expect(result.isSuccess, isTrue);

      final (event, props) = analytics.events.single;
      expect(event, AppEvent.bulkPriceUpdated);
      expect(props, {'count': 2, 'durationMs': 42000, 'mode': 'percent'});
      expect(repository.changes.map((c) => c.batchId).toSet().length, 1,
          reason: 'one batch id for the whole update');
    });

    test('reports the batch id, the rows and the summary numbers', () async {
      final usecase = ApplyBulkPrices(
        repository: repository,
        session: FakeSession.ownerSession,
        analytics: analytics,
      );
      final batch = (await usecase(rule(), duration: Duration.zero)).valueOrNull!;
      expect(batch.batchId, isNotEmpty);
      expect(batch.count, 2);
      expect(batch.increased, 2);
      expect(batch.decreased, 0);
      expect(batch.averagePercent, closeTo(10, 0.5));
    });

    test('a repository failure is passed through and nothing is logged', () async {
      repository.applyFailure = const StorageFailure('boom');
      final usecase = ApplyBulkPrices(
        repository: repository,
        session: FakeSession.ownerSession,
        analytics: analytics,
      );
      final result = await usecase(rule(), duration: Duration.zero);
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(analytics.events, isEmpty);
    });
  });

  group('GetProductPricing', () {
    test('returns the product row the preview found', () async {
      final usecase =
          GetProductPricing(repository: repository, session: FakeSession.ownerSession);
      final result = await usecase('prod-1');
      expect(result.valueOrNull!.productName, 'Milk 1L');
    });

    test('an unknown product is a NotFoundFailure', () async {
      final usecase =
          GetProductPricing(repository: repository, session: FakeSession.ownerSession);
      expect((await usecase('nope')).failureOrNull, isA<NotFoundFailure>());
    });
  });
}
