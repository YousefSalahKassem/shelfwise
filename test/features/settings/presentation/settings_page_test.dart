import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_impl.dart';
import 'package:shelfwise/core/session/session_reader.dart';
import 'package:shelfwise/core/settings/preferences_impl.dart';
import 'package:shelfwise/features/onboarding/data/store_providers.dart';
import 'package:shelfwise/features/settings/presentation/pages/settings_page.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_app.dart';
import '../../onboarding/support/fake_store_repository.dart';

void main() {
  late FakeStoreRepository repository;

  setUp(() {
    repository = FakeStoreRepository(store: FakeSession.store, branch: FakeSession.branch);
  });

  List<Override> overrides() => [storeRepositoryProvider.overrideWithValue(repository)];

  Future<void> pumpPage(
    WidgetTester tester, {
    SessionState session = FakeSession.ownerSession,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      const SettingsPage(),
      locale: locale,
      brand: Fixtures.brand(defaultLocale: locale.languageCode),
      session: session,
      overrides: overrides(),
    );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));

  testWidgets('the owner sees appearance, security, store, data and about', (tester) async {
    await pumpPage(tester);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
    expect(find.text('Profiles'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });

  testWidgets('staff see appearance but no owner-only sections', (tester) async {
    await pumpPage(tester, session: FakeSession.staffSession);

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Store'), findsNothing);
    expect(find.text('Profiles'), findsNothing);
    expect(find.text('Backup & restore'), findsNothing);
    expect(find.text('Import products'), findsNothing);
  });

  testWidgets('changing theme, language and digits updates the preferences', (tester) async {
    await pumpPage(tester);
    final container = containerOf(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(container.read(preferencesControllerProvider).themeMode, ThemeMode.dark);

    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(container.read(preferencesControllerProvider).locale, const Locale('ar'));

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(container.read(preferencesControllerProvider).latinDigits, isFalse);
  });

  testWidgets('the owner renames the store and the session picks it up', (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextField), 'Nour Express');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.store?.name, 'Nour Express');
    expect(containerOf(tester).read(sessionControllerProvider).store?.name, 'Nour Express');
    expect(find.text('Store details saved.'), findsOneWidget);
  });

  testWidgets('"lock now" locks the app', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Lock now'));
    await tester.pumpAndSettle();

    expect(containerOf(tester).read(sessionControllerProvider).isUnlocked, isFalse);
  });

  testWidgets('the owner can turn auto-lock off', (tester) async {
    await pumpPage(tester);
    final container = containerOf(tester);
    expect(container.read(preferencesControllerProvider).autoLockMinutes, 5);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never').last);
    await tester.pumpAndSettle();

    expect(container.read(preferencesControllerProvider).autoLockMinutes, 0);
  });

  testWidgets('staff cannot change the auto-lock time', (tester) async {
    await pumpPage(tester, session: FakeSession.staffSession);

    expect(tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>)).onChanged, isNull);
  });

  testWidgets('Arabic renders right-to-left with translated labels', (tester) async {
    await pumpPage(tester, locale: const Locale('ar'));

    final context = tester.element(find.byType(SettingsPage));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('الأمان'), findsOneWidget);
  });
}
