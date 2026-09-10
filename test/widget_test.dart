import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/app.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/l10n/l10n.dart';
import 'package:shelfwise/core/router/app_router.dart';
import 'package:shelfwise/core/router/route_paths.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/settings/preferences_impl.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_app.dart';

void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(400, 800),
    SessionState session = FakeSession.ownerSession,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: baseOverrides(brand: Fixtures.brand(defaultLocale: locale), session: session),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShelfWiseApp()));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('boots to the dashboard placeholder with bottom navigation', (tester) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('store language wins over brand default; Arabic renders right-to-left', (tester) async {
    // Locale priority: device preference → profile → store → brand default.
    final arabicStore = SessionState(
      store: FakeSession.store.copyWith(locale: 'ar'),
      branch: FakeSession.branch,
      profile: FakeSession.owner,
    );
    await pumpApp(tester, session: arabicStore);
    final context = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('الرئيسية'), findsWidgets);
  });

  testWidgets('switching language and theme at runtime', (tester) async {
    final container = await pumpApp(tester);
    container.read(preferencesControllerProvider.notifier)
      ..setLocale(const Locale('ar'))
      ..setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(AppLocalizations.of(context).common_navSettings, 'الإعدادات');
  });

  testWidgets('wide screens use a navigation rail', (tester) async {
    await pumpApp(tester, size: const Size(1200, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('staff doesn\'t see owner-only settings links', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: baseOverrides(brand: Fixtures.brand(tier: Tier.shelf), session: FakeSession.staffSession),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ShelfWiseApp()));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go(RoutePaths.settings);
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Profiles'), findsNothing);
    expect(find.text('Backup & restore'), findsNothing);
  });
}
