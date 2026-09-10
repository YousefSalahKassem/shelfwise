import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/brand/brand_providers.dart';
import 'package:shelfwise/core/router/guards.dart';
import 'package:shelfwise/core/router/route_paths.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/session/session_impl.dart';
import 'package:shelfwise/core/settings/preferences_impl.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/core_providers.dart';
import 'package:shelfwise/features/onboarding/data/store_providers.dart';
import 'package:shelfwise/features/onboarding/domain/repositories/store_repository.dart';

import '../../helpers/fixtures.dart';
import '../onboarding/support/fake_store_repository.dart';

void main() {
  late FakeStoreRepository repository;

  setUp(() => repository = FakeStoreRepository());

  ProviderContainer containerWith() {
    final container = ProviderContainer(
      overrides: [
        brandConfigProvider.overrideWithValue(Fixtures.brand()),
        storeRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('before onboarding the session is empty, which routes to /onboarding', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;

    final state = container.read(sessionControllerProvider);
    expect(state.hasStore, isFalse);
    expect(state.isUnlocked, isFalse);
    expect(
      redirectFor(
        location: RoutePaths.dashboard,
        session: state,
        flags: container.read(featureFlagsProvider),
      ),
      RoutePaths.onboarding,
    );
  });

  test('a restart restores the store but stays locked', () async {
    repository
      ..store = FakeSession.store
      ..branch = FakeSession.branch;

    final container = containerWith();
    await container.read(sessionControllerProvider.notifier).restored;

    final state = container.read(sessionControllerProvider);
    expect(state.store, FakeSession.store);
    expect(state.branch, FakeSession.branch);
    expect(state.profile, isNull);
    expect(state.isUnlocked, isFalse);
    expect(
      redirectFor(
        location: RoutePaths.dashboard,
        session: state,
        flags: container.read(featureFlagsProvider),
      ),
      RoutePaths.lock,
    );
  });

  test('onboarding signs the owner in', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;

    controller.startSession(
      const StoreSetup(
        store: FakeSession.store,
        branch: FakeSession.branch,
        owner: FakeSession.owner,
      ),
    );

    final state = container.read(sessionControllerProvider);
    expect(state.isUnlocked, isTrue);
    expect(state.can(Permission.manageProfiles), isTrue);
  });

  test('unlock, lock and unlock again as another profile', () async {
    repository
      ..store = FakeSession.store
      ..branch = FakeSession.branch;
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;

    controller.unlock(FakeSession.owner);
    expect(container.read(sessionControllerProvider).isUnlocked, isTrue);

    controller.lock();
    var state = container.read(sessionControllerProvider);
    expect(state.isUnlocked, isFalse);
    expect(state.store, isNotNull, reason: 'the store stays known while locked');
    expect(state.profile, FakeSession.owner, reason: 'so the lock screen can preselect');

    controller.unlock(FakeSession.staff);
    state = container.read(sessionControllerProvider);
    expect(state.profile, FakeSession.staff);
    expect(state.can(Permission.editPrices), isFalse);
  });

  test('locking before onboarding does nothing', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;

    controller.lock();
    expect(container.read(sessionControllerProvider), isNotNull);
    expect(container.read(sessionControllerProvider).hasStore, isFalse);
  });

  test('a renamed store and profile are reflected in the session', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;
    controller.startSession(
      const StoreSetup(
        store: FakeSession.store,
        branch: FakeSession.branch,
        owner: FakeSession.owner,
      ),
    );

    controller.applyStore(FakeSession.store.copyWith(name: 'Nour Express', currency: 'SAR'));
    expect(container.read(sessionControllerProvider).store?.name, 'Nour Express');

    controller.applyProfile(FakeSession.owner.copyWith(name: 'Karim A.'));
    expect(container.read(sessionControllerProvider).profile?.name, 'Karim A.');
  });

  test('deactivating the signed-in profile locks the app immediately', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;
    controller.startSession(
      const StoreSetup(
        store: FakeSession.store,
        branch: FakeSession.branch,
        owner: FakeSession.staff,
      ),
    );

    controller.applyProfile(FakeSession.staff.copyWith(isActive: false));

    final state = container.read(sessionControllerProvider);
    expect(state.isUnlocked, isFalse);
    expect(state.profile, isNull);
  });

  test('a change to another profile leaves the session alone', () async {
    final container = containerWith();
    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;
    controller.startSession(
      const StoreSetup(
        store: FakeSession.store,
        branch: FakeSession.branch,
        owner: FakeSession.owner,
      ),
    );

    controller.applyProfile(FakeSession.staff.copyWith(isActive: false));
    expect(container.read(sessionControllerProvider).profile, FakeSession.owner);
  });

  testWidgets('the app locks itself after the auto-lock time without input', (tester) async {
    repository
      ..store = FakeSession.store
      ..branch = FakeSession.branch;
    final clock = FixedClock(Fixtures.now);
    final container = ProviderContainer(
      overrides: [
        brandConfigProvider.overrideWithValue(Fixtures.brand()),
        storeRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;
    container.read(preferencesControllerProvider.notifier).setAutoLockMinutes(1);
    controller.unlock(FakeSession.owner);
    expect(container.read(sessionControllerProvider).isUnlocked, isTrue);

    clock.advance(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 30));
    expect(container.read(sessionControllerProvider).isUnlocked, isTrue);

    clock.advance(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(container.read(sessionControllerProvider).isUnlocked, isFalse);
    expect(
      container.read(sessionControllerProvider).store,
      isNotNull,
      reason: 'locking keeps the store, so the lock screen can list its profiles',
    );
  });

  testWidgets('"never" keeps the app unlocked', (tester) async {
    final clock = FixedClock(Fixtures.now);
    final container = ProviderContainer(
      overrides: [
        brandConfigProvider.overrideWithValue(Fixtures.brand()),
        storeRepositoryProvider.overrideWithValue(repository),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(sessionControllerProvider.notifier);
    await controller.restored;
    container.read(preferencesControllerProvider.notifier).setAutoLockMinutes(0);
    controller.startSession(
      const StoreSetup(
        store: FakeSession.store,
        branch: FakeSession.branch,
        owner: FakeSession.owner,
      ),
    );

    clock.advance(const Duration(hours: 2));
    await tester.pump(const Duration(hours: 2));
    expect(container.read(sessionControllerProvider).isUnlocked, isTrue);
  });
}
