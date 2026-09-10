import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/database_providers.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/features/pricing/presentation/pages/single_price_page.dart';
import 'package:shelfwise/features/pricing/presentation/providers/pricing_providers.dart';

import '../../../helpers/test_app.dart';
import '../../../helpers/test_db.dart';
import '../support/fake_pricing_repository.dart';

void main() {
  late FakePricingRepository repository;
  // Only needed so the shared preference/settings providers can build; pricing
  // itself goes through [FakePricingRepository] (sqflite futures never
  // complete inside a widget test's fake-async zone).
  late AppDatabase db;

  setUp(() async {
    repository = FakePricingRepository();
    db = await openTestDatabase();
  });

  tearDown(() async => db.close());

  FakeProduct milk() => repository.products.first;

  Future<void> pumpPage(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    SessionState session = FakeSession.ownerSession,
  }) =>
      pumpTestWidget(
        tester,
        const SinglePricePage(productId: 'prod-1'),
        locale: locale,
        session: session,
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          pricingRepositoryProvider.overrideWithValue(repository),
        ],
      );

  testWidgets('shows the product, its current price and the live margin', (tester) async {
    await pumpPage(tester);

    expect(find.text('Milk 1L'), findsOneWidget);
    // 15.10 price, 10.10 cost → margin 33.1%
    expect(find.textContaining('33.1'), findsOneWidget);
    expect(find.widgetWithText(TextField, '15.10'), findsOneWidget);
  });

  testWidgets('the margin follows what you type', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, '20.00');
    await tester.pump();

    expect(find.textContaining('49.5'), findsOneWidget);
  });

  testWidgets('warns when the new price is below cost', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, '5.00');
    await tester.pump();

    expect(find.text('This price is below cost.'), findsOneWidget);
  });

  testWidgets('warns when the new price is zero', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, '0');
    await tester.pump();

    expect(find.text('This product would be free.'), findsOneWidget);
  });

  testWidgets('saving writes the price and the cost and confirms', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, '25.00');
    await tester.enterText(find.byType(TextField).last, '12.00');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();

    expect(milk().priceMinor, 2500);
    expect(milk().costMinor, 1200);
    expect(repository.changes.single.batchId, isNull, reason: 'a single edit is not a batch');
    expect(find.text('Price updated'), findsOneWidget);
  });

  testWidgets('rejects an unparseable price without writing', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField).first, 'abc');
    await tester.tap(find.text('Save price'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a price like 12.50.'), findsOneWidget);
    expect(milk().priceMinor, 1510);
    expect(repository.calls.where((c) => c.startsWith('updatePrice')), isEmpty);
  });

  testWidgets('a staff profile that reaches the screen cannot see or change prices',
      (tester) async {
    await pumpPage(tester, session: FakeSession.staffSession);

    expect(
      find.text("Your profile isn't allowed to do this. Ask the store owner."),
      findsOneWidget,
    );
    expect(find.text('Save price'), findsNothing);
  });

  testWidgets('lays out right-to-left in Arabic', (tester) async {
    await pumpPage(tester, locale: const Locale('ar'));

    expect(find.text('تغيير السعر'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('Milk 1L'))), TextDirection.rtl);
  });
}
