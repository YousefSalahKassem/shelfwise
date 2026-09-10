import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_impl.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/core_providers.dart';
import 'package:shelfwise/features/profiles/data/profile_providers.dart';
import 'package:shelfwise/features/profiles/presentation/pages/lock_page.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_app.dart';
import '../support/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository repository;
  late RecordingAnalyticsService analytics;
  late FixedClock clock;

  setUp(() {
    repository = FakeProfileRepository();
    analytics = RecordingAnalyticsService();
    clock = FixedClock(Fixtures.now);
  });

  tearDown(() => repository.dispose());

  List<Override> overrides() => [
        profileRepositoryProvider.overrideWithValue(repository),
        analyticsServiceProvider.overrideWithValue(analytics),
        clockProvider.overrideWithValue(clock),
      ];

  Future<void> pumpPage(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    SessionState session = FakeSession.locked,
  }) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      const LockPage(),
      locale: locale,
      brand: Fixtures.brand(defaultLocale: locale.languageCode),
      session: session,
      overrides: overrides(),
    );
  }

  Future<void> enterPin(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.widgetWithText(TextButton, digit));
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
  }

  SessionState sessionOf(WidgetTester tester) => ProviderScope.containerOf(
        tester.element(find.byType(LockPage)),
      ).read(sessionControllerProvider);

  testWidgets('lists the active profiles with their roles', (tester) async {
    await pumpPage(tester);

    expect(find.text("Who's using the app?"), findsOneWidget);
    expect(find.text('Karim'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(find.text('Mona'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
  });

  testWidgets('deactivated profiles are not offered', (tester) async {
    await repository.deactivate(FakeSession.staff.id);
    await pumpPage(tester);

    expect(find.text('Karim'), findsOneWidget);
    expect(find.text('Mona'), findsNothing);
  });

  testWidgets('the right PIN unlocks the app and logs session_started', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Karim'));
    await tester.pumpAndSettle();
    await enterPin(tester, '1234');

    final session = sessionOf(tester);
    expect(session.isUnlocked, isTrue);
    expect(session.profile?.id, FakeSession.owner.id);
    expect(analytics.events.single.$1, AppEvent.sessionStarted);
  });

  testWidgets('switching from a signed-in profile logs profile_switched', (tester) async {
    await pumpPage(
      tester,
      session: const SessionState(
        store: FakeSession.store,
        branch: FakeSession.branch,
        profile: FakeSession.owner,
        locked: true,
      ),
    );

    await tester.tap(find.text('Mona'));
    await tester.pumpAndSettle();
    await enterPin(tester, '5678');

    expect(sessionOf(tester).profile?.id, FakeSession.staff.id);
    expect(analytics.events.single.$1, AppEvent.profileSwitched);
  });

  testWidgets('a wrong PIN shows a message and keeps the app locked', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Karim'));
    await tester.pumpAndSettle();
    await enterPin(tester, '9999');

    expect(find.text('Wrong PIN. Try again.'), findsOneWidget);
    expect(sessionOf(tester).isUnlocked, isFalse);
  });

  testWidgets('five wrong PINs freeze the pad until the cooldown ends', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Karim'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await enterPin(tester, '9999');
    }

    expect(find.textContaining('Too many wrong tries'), findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, '1')).onPressed, isNull);

    // Let the countdown run out; the clock the use case reads is fixed, so move
    // it forward too.
    clock.advance(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.textContaining('Too many wrong tries'), findsNothing);
    await enterPin(tester, '1234');
    expect(sessionOf(tester).isUnlocked, isTrue);
  });

  testWidgets('a store with no active profile says so instead of showing an empty grid',
      (tester) async {
    await repository.deactivate(FakeSession.owner.id);
    await repository.deactivate(FakeSession.staff.id);
    await pumpPage(tester);

    expect(find.text('No profile can unlock this device. Ask the owner.'), findsOneWidget);
  });

  testWidgets('Arabic renders right-to-left with translated labels', (tester) async {
    await pumpPage(tester, locale: const Locale('ar'));

    final context = tester.element(find.byType(LockPage));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('من يستخدم التطبيق؟'), findsOneWidget);
    expect(find.text('المالك'), findsOneWidget);
  });
}
