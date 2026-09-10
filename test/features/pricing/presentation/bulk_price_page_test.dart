import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/database_providers.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/features/pricing/data/models/pricing_rows.dart';
import 'package:shelfwise/features/pricing/presentation/pages/bulk_price_page.dart';
import 'package:shelfwise/features/pricing/presentation/providers/pricing_providers.dart';
import 'package:shelfwise/features/pricing/presentation/widgets/preview_tile.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_db.dart';
import '../support/fake_pricing_repository.dart';

void main() {
  late FakePricingRepository repository;
  late RecordingAnalyticsService analytics;
  late AppDatabase db;

  setUp(() async {
    repository = FakePricingRepository(parentOf: const {'cat-cheese': 'cat-dairy'});
    analytics = RecordingAnalyticsService();
    db = await openTestDatabase();
  });

  tearDown(() async => db.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    String ids = 'prod-1,prod-2',
    Locale locale = const Locale('en'),
    SessionState session = FakeSession.ownerSession,
  }) {
    // A tall viewport so the whole form is built (a ListView only builds what
    // it can show, and the real screen scrolls).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpTestWidget(
        tester,
        BulkPricePage(initialIds: ids),
        locale: locale,
        session: session,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pricingRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(analytics),
          // Delivered asynchronously: a stream that emits during the first
          // build would modify a provider while the tree is building.
          pricingCategoriesProvider.overrideWith(
            (ref) => Stream.fromFuture(
              Future.value(const [
                CategoryOptionRow(id: 'cat-dairy', name: 'Dairy'),
                CategoryOptionRow(id: 'cat-cheese', name: 'Cheese', parentId: 'cat-dairy'),
              ]),
            ),
          ),
        ],
      );
  }

  Future<void> enterPercent(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('pricing_amountField')), value);
    await tester.pump();
  }

  Future<void> showPreview(WidgetTester tester) async {
    await tester.tap(find.text('Preview changes'));
    await tester.pumpAndSettle();
  }

  Future<void> confirmApply(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Apply')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('preselected products from ?ids= start in the selection scope', (tester) async {
    await pumpPage(tester);

    expect(find.text('2 products chosen'), findsOneWidget);
  });

  testWidgets('the preview shows old to new prices and does not write', (tester) async {
    await pumpPage(tester);
    await enterPercent(tester, '10');
    await showPreview(tester);

    expect(find.byType(PreviewTile), findsNWidgets(2));
    expect(find.text('2 products change'), findsOneWidget);
    expect(find.textContaining('16.61'), findsOneWidget, reason: '15.10 + 10%');
    expect(repository.changes, isEmpty, reason: 'preview must not write');
  });

  testWidgets('rounding is applied to the preview', (tester) async {
    await pumpPage(tester);
    await enterPercent(tester, '10');
    await tester.tap(find.byKey(const Key('pricing_roundingField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('0.25').last);
    await tester.pumpAndSettle();
    await showPreview(tester);

    expect(find.textContaining('16.50'), findsOneWidget, reason: '16.61 rounded to 0.25');
  });

  testWidgets('a decrease that goes below cost is flagged', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('Decrease'));
    await tester.pump();
    await enterPercent(tester, '50');
    await showPreview(tester);

    expect(find.text('Below cost'), findsNWidgets(2));
  });

  testWidgets('applying writes one batch, logs the pilot event and shows the summary',
      (tester) async {
    await pumpPage(tester);
    await enterPercent(tester, '10');
    await showPreview(tester);
    await confirmApply(tester);

    expect(repository.products.first.priceMinor, 1661);
    expect(repository.products[1].priceMinor, 2200);
    expect(repository.changes.map((c) => c.batchId).toSet().length, 1);

    final (event, props) = analytics.events.single;
    expect(event, AppEvent.bulkPriceUpdated);
    expect(props['count'], 2);
    expect(props['mode'], 'percent');
    expect(props['durationMs'], isA<int>());

    expect(find.text('Prices updated'), findsOneWidget);
    expect(find.text('2 products changed'), findsOneWidget);
    expect(find.textContaining('Average change'), findsOneWidget);
    expect(find.text('View changes'), findsOneWidget);
    expect(find.byType(PreviewTile), findsNWidgets(2));
  });

  testWidgets('Back returns to the form without applying', (tester) async {
    await pumpPage(tester);
    await enterPercent(tester, '10');
    await showPreview(tester);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(PreviewTile), findsNothing);
    expect(find.text('Preview changes'), findsOneWidget);
    expect(repository.changes, isEmpty);
  });

  testWidgets('the amount is required before a preview', (tester) async {
    await pumpPage(tester);
    await showPreview(tester);

    expect(find.text('Enter how much to change prices by.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('a scope is required before a preview', (tester) async {
    await pumpPage(tester, ids: '');
    await enterPercent(tester, '10');
    await showPreview(tester);

    expect(find.text('Choose a category or pick some products.'), findsOneWidget);
    expect(repository.calls, isEmpty);
  });

  testWidgets('a category scope reprices its sub-categories too', (tester) async {
    await pumpPage(tester, ids: '');
    await tester.tap(find.byKey(const Key('pricing_categoryField')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dairy').last);
    await tester.pumpAndSettle();
    await enterPercent(tester, '10');
    await showPreview(tester);

    expect(
      find.byType(PreviewTile),
      findsNWidgets(2),
      reason: 'Dairy plus its Cheese sub-category',
    );
  });

  testWidgets('staff cannot preview or apply: the use case refuses', (tester) async {
    await pumpPage(tester, session: FakeSession.staffSession);
    await enterPercent(tester, '10');
    await showPreview(tester);

    expect(
      find.text("Your profile isn't allowed to do this. Ask the store owner."),
      findsOneWidget,
    );
    expect(repository.calls, isEmpty);
  });

  testWidgets('lays out right-to-left in Arabic', (tester) async {
    await pumpPage(tester, locale: const Locale('ar'));
    await enterPercent(tester, '10');
    await tester.tap(find.text('معاينة التغييرات'));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(PreviewTile).first)),
      TextDirection.rtl,
    );
  });
}
