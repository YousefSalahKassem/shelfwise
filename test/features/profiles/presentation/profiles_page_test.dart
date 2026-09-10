import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/brand/tier.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/features/profiles/data/profile_providers.dart';
import 'package:shelfwise/features/profiles/presentation/pages/profiles_page.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_app.dart';
import '../support/fake_profile_repository.dart';

void main() {
  late FakeProfileRepository repository;

  setUp(() => repository = FakeProfileRepository());
  tearDown(() => repository.dispose());

  List<Override> overrides() => [profileRepositoryProvider.overrideWithValue(repository)];

  Future<void> pumpPage(WidgetTester tester, {Tier tier = Tier.aisle}) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpTestWidget(
      tester,
      const ProfilesPage(),
      brand: Fixtures.brand(tier: tier),
      overrides: overrides(),
    );
  }

  Future<void> addStaff(WidgetTester tester, String name, String pin) async {
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    for (var round = 0; round < 2; round++) {
      for (final digit in pin.split('')) {
        await tester.tap(find.widgetWithText(TextButton, digit));
        await tester.pump();
      }
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('lists the profiles grouped by active and inactive', (tester) async {
    await repository.create(name: 'Sara', role: FakeSession.staff.role, pin: '1111');
    await repository.deactivate('profile-1');
    await pumpPage(tester);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Karim'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
  });

  testWidgets('the owner adds a staff profile', (tester) async {
    await pumpPage(tester);

    await addStaff(tester, 'Sara', '4321');

    expect(repository.profiles.map((p) => p.name), contains('Sara'));
    expect(repository.pins.values, contains('4321'));
    expect(find.text('Profile added.'), findsOneWidget);
  });

  testWidgets('a shelf brand blocks the fourth staff profile with an upgrade hint',
      (tester) async {
    // The fixture starts with one staff profile; two more fill the plan.
    await repository.create(name: 'B', role: FakeSession.staff.role, pin: '1111');
    await repository.create(name: 'C', role: FakeSession.staff.role, pin: '1111');
    await pumpPage(tester, tier: Tier.shelf);

    await addStaff(tester, 'D', '4321');

    expect(
      find.text('Your plan includes 3 staff profiles. Upgrade the plan to add more.'),
      findsOneWidget,
    );
    expect(repository.profiles.map((p) => p.name), isNot(contains('D')));
  });

  testWidgets('the same brand on the aisle plan allows it', (tester) async {
    await repository.create(name: 'B', role: FakeSession.staff.role, pin: '1111');
    await repository.create(name: 'C', role: FakeSession.staff.role, pin: '1111');
    await pumpPage(tester, tier: Tier.aisle);

    await addStaff(tester, 'D', '4321');

    expect(repository.profiles.map((p) => p.name), contains('D'));
  });

  testWidgets('the owner profile offers no deactivate action', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Deactivate'), findsNothing);
    expect(find.text('Change PIN'), findsOneWidget);
  });

  testWidgets('a staff profile is deactivated after confirmation', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();

    expect(repository.profiles.firstWhere((p) => p.id == FakeSession.staff.id).isActive, isFalse);
  });
}
