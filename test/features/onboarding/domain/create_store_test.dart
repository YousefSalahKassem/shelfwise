import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/analytics/analytics_service.dart';
import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/error/result.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/features/onboarding/domain/repositories/store_repository.dart';
import 'package:shelfwise/features/onboarding/domain/usecases/create_store.dart';
import 'package:shelfwise/features/onboarding/domain/usecases/update_store.dart';
import 'package:shelfwise/features/profiles/domain/value_objects/pin.dart';

import '../support/fake_store_repository.dart';

void main() {
  late FakeStoreRepository repository;
  late RecordingAnalyticsService analytics;
  late CreateStore createStore;

  setUp(() {
    repository = FakeStoreRepository();
    analytics = RecordingAnalyticsService();
    createStore = CreateStore(repository: repository, analytics: analytics);
  });

  Future<Result<StoreSetup>> create({
    String storeName = 'Al Nour Market',
    String currency = 'EGP',
    String locale = 'ar',
    String ownerName = 'Karim',
    String pin = '1234',
  }) =>
      createStore(
        storeName: storeName,
        currency: currency,
        locale: locale,
        ownerName: ownerName,
        pin: pin,
      );

  test('creates the store, its default branch and the owner, and logs store_created', () async {
    final result = await createStore(
      storeName: '  Al Nour Market  ',
      currency: 'SAR',
      locale: 'ar',
      ownerName: '  Karim  ',
      pin: '482913',
    );

    final setup = result.valueOrNull!;
    expect(setup.store.name, 'Al Nour Market');
    expect(setup.store.currency, 'SAR');
    expect(setup.store.locale, 'ar');
    expect(setup.branch.isDefault, isTrue);
    expect(setup.owner.name, 'Karim');
    expect(setup.owner.role, Role.owner);
    expect(repository.createdPin, '482913');
    expect(analytics.events.single.$1, AppEvent.storeCreated);
  });

  test('a store name is required', () async {
    final result = await create(storeName: '   ');
    expect(
      result.failureOrNull,
      isA<ValidationFailure>().having((f) => f.field, 'field', 'storeName'),
    );
    expect(analytics.events, isEmpty);
  });

  test('an owner name is required', () async {
    final result = await create(ownerName: '');
    expect(
      result.failureOrNull,
      isA<ValidationFailure>().having((f) => f.field, 'field', 'ownerName'),
    );
  });

  test('the PIN must be 4 to 6 digits', () async {
    for (final pin in ['', '12', '123', '1234567', 'abcd']) {
      final result = await create(pin: pin);
      expect(
        result.failureOrNull,
        isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.length),
        reason: pin,
      );
    }
  });

  test('a second store is refused on the same device', () async {
    await create();
    final again = await create(storeName: 'Second');
    expect(again.failureOrNull, isA<ConflictFailure>());
  });

  group('UpdateStore', () {
    test('the owner can rename the store and change its currency', () async {
      await create();
      final result = await UpdateStore(
        repository: repository,
        session: FakeSession.ownerSession,
      )(name: '  New Name  ', currency: 'SAR');

      expect(result.valueOrNull?.name, 'New Name');
      expect(result.valueOrNull?.currency, 'SAR');
    });

    test('staff cannot change store details', () async {
      await create();
      final result = await UpdateStore(
        repository: repository,
        session: FakeSession.staffSession,
      )(name: 'New Name', currency: 'EGP');

      expect(result.failureOrNull, isA<PermissionFailure>());
    });

    test('rejects an empty name and an unsupported currency', () async {
      await create();
      final update = UpdateStore(repository: repository, session: FakeSession.ownerSession);

      expect((await update(name: ' ', currency: 'EGP')).failureOrNull, isA<ValidationFailure>());
      expect((await update(name: 'Ok', currency: 'USD')).failureOrNull, isA<ValidationFailure>());
    });
  });
}
