import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_impl.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/features/onboarding/data/store_providers.dart';
import 'package:shelfwise/features/onboarding/presentation/pages/onboarding_page.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_app.dart';
import '../support/fake_store_repository.dart';

void main() {
  late FakeStoreRepository repository;
  late RecordingAnalyticsService analytics;

  setUp(() {
    repository = FakeStoreRepository();
    analytics = RecordingAnalyticsService();
  });

  List<Override> overrides() => [
        storeRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(analytics),
      ];

  Future<void> pumpPage(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      const OnboardingPage(),
      locale: locale,
      brand: Fixtures.brand(defaultLocale: locale.languageCode),
      session: FakeSession.noStore,
      overrides: overrides(),
    );
  }

  /// Taps [digits] on the pad and confirms. Plain pumps rather than
  /// `pumpAndSettle`: a successful confirmation shows a progress indicator that
  /// never settles (in the app the router leaves the page at that point).
  Future<void> enterPin(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> fillStoreAndOwner(
    WidgetTester tester, {
    String store = 'Al Nour Market',
    String owner = 'Karim',
  }) async {
    await tester.enterText(find.byType(TextField), store);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), owner);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  SessionState sessionOf(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(OnboardingPage)),
      ).read(sessionControllerProvider);

  testWidgets('walks through store, owner and PIN, then signs the owner in', (tester) async {
    await pumpPage(tester);
    expect(find.text('Welcome to ShelfWise'), findsOneWidget);

    await fillStoreAndOwner(tester);
    await enterPin(tester, '4829');
    expect(find.text('Enter the PIN again'), findsOneWidget);
    await enterPin(tester, '4829');

    expect(repository.store?.name, 'Al Nour Market');
    expect(repository.store?.currency, 'EGP');
    expect(repository.branch?.isDefault, isTrue);
    expect(repository.createdPin, '4829');
    expect(analytics.events.single.$1, AppEvent.storeCreated);

    // Signing the owner in is what takes the router off /onboarding.
    final session = sessionOf(tester);
    expect(session.hasStore, isTrue);
    expect(session.isUnlocked, isTrue);
    expect(session.profile?.name, 'Karim');
  });

  testWidgets('refuses to continue without a store name or an owner name', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a store name.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Al Nour Market');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(repository.store, isNull);
  });

  testWidgets('a mismatched confirmation asks for the PIN again', (tester) async {
    await pumpPage(tester);
    await fillStoreAndOwner(tester);

    await enterPin(tester, '1234');
    await enterPin(tester, '9999');

    expect(find.text('The two PINs are different. Start again.'), findsOneWidget);
    expect(repository.store, isNull);
  });

  testWidgets('a 6-digit PIN is accepted', (tester) async {
    await pumpPage(tester);
    await fillStoreAndOwner(tester);

    await enterPin(tester, '482913');
    await enterPin(tester, '482913');

    expect(repository.createdPin, '482913');
  });

  testWidgets('the chosen language is stored on the store', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Al Nour Market');
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Karim');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await enterPin(tester, '1234');
    await enterPin(tester, '1234');

    expect(repository.store?.locale, 'ar');
  });

  testWidgets('Arabic renders right-to-left with translated labels', (tester) async {
    await pumpPage(tester, locale: const Locale('ar'));

    final context = tester.element(find.byType(OnboardingPage));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('إعداد متجرك'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
  });
}
