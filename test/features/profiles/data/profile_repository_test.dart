import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/features/profiles/data/datasources/profile_local_data_source.dart';
import 'package:shelfwise/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:shelfwise/features/profiles/domain/services/pin_hasher.dart';
import 'package:shelfwise/features/profiles/domain/value_objects/pin.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_db.dart';

void main() {
  const hasher = PinHasher(iterations: 100);

  late AppDatabase db;
  late DbChanges changes;
  late ProfileRepositoryImpl repository;

  setUp(() async {
    db = await openTestDatabase();
    await Fixtures.seed(db);
    changes = DbChanges();
    repository = ProfileRepositoryImpl(
      local: ProfileLocalDataSource(
        db: db,
        clock: FixedClock(Fixtures.now),
        ids: SequentialIdGenerator('staff'),
        hasher: hasher,
      ),
      changes: changes,
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  test('lists the seeded profiles, owner first', () async {
    final profiles = await repository.watchAll().first;
    expect(profiles.map((p) => p.id), [FakeSession.owner.id, FakeSession.staff.id]);
    expect(profiles.first.role, Role.owner);
  });

  test('creates a staff profile with a hashed PIN and notifies listeners', () async {
    final tables = <Set<DbTable>>[];
    changes.watch({DbTable.profiles}).listen(tables.add);

    final created = (await repository.create(
      name: 'Sara',
      role: Role.staff,
      pin: '4321',
      locale: 'ar',
    ))
        .valueOrNull!;

    expect(created.name, 'Sara');
    expect(created.role, Role.staff);
    expect(created.locale, 'ar');
    expect(created.isActive, isTrue);

    final row = (await db.db.query(T.profiles, where: 'id = ?', whereArgs: [created.id])).single;
    expect(row['pin_hash'], isNot(contains('4321')));
    expect(
      hasher.verify(
        pin: '4321',
        hash: row['pin_hash']! as String,
        salt: row['pin_salt']! as String,
      ),
      isTrue,
    );

    await pumpEventQueue();
    expect(tables, isNotEmpty);
  });

  test('verifies the right PIN and rejects a wrong one', () async {
    final created = (await repository.create(name: 'Sara', role: Role.staff, pin: '4321'))
        .valueOrNull!;

    expect((await repository.verifyPin(created.id, '4321')).valueOrNull?.id, created.id);

    final wrong = await repository.verifyPin(created.id, '1111');
    expect(
      wrong.failureOrNull,
      isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.wrongPin),
    );
  });

  test('unreadable stored PIN material is a wrong PIN, not a crash', () async {
    // The fixture seeds placeholder credentials that are not valid base64.
    final result = await repository.verifyPin(FakeSession.owner.id, '1234');
    expect(
      result.failureOrNull,
      isA<ValidationFailure>().having((f) => f.code, 'code', PinFailureCodes.wrongPin),
    );
  });

  test('a deactivated profile cannot be verified, and stays in the table', () async {
    final created = (await repository.create(name: 'Sara', role: Role.staff, pin: '4321'))
        .valueOrNull!;

    expect((await repository.deactivate(created.id)).isSuccess, isTrue);

    final profiles = await repository.watchAll().first;
    expect(profiles.where((p) => p.id == created.id).single.isActive, isFalse);
    expect((await repository.verifyPin(created.id, '4321')).isSuccess, isFalse);
    expect(
      (await db.db.query(T.profiles, where: 'id = ?', whereArgs: [created.id])).length,
      1,
      reason: 'profiles are never deleted — stock movements reference them',
    );
  });

  test('reactivating through update makes the profile usable again', () async {
    final created = (await repository.create(name: 'Sara', role: Role.staff, pin: '4321'))
        .valueOrNull!;
    await repository.deactivate(created.id);

    await repository.update(created.copyWith(isActive: true, name: 'Sara A.', locale: 'en'));

    final profile = (await repository.watchAll().first).firstWhere((p) => p.id == created.id);
    expect(profile.isActive, isTrue);
    expect(profile.name, 'Sara A.');
    expect(profile.locale, 'en');
    expect((await repository.verifyPin(created.id, '4321')).isSuccess, isTrue);
  });

  test('resetting a PIN replaces the old one', () async {
    final created = (await repository.create(name: 'Sara', role: Role.staff, pin: '4321'))
        .valueOrNull!;

    expect((await repository.resetPin(created.id, '9876')).isSuccess, isTrue);
    expect((await repository.verifyPin(created.id, '4321')).isSuccess, isFalse);
    expect((await repository.verifyPin(created.id, '9876')).isSuccess, isTrue);
  });

  test('unknown profiles report not found', () async {
    expect((await repository.resetPin('nope', '1234')).failureOrNull, isA<NotFoundFailure>());
    expect((await repository.deactivate('nope')).failureOrNull, isA<NotFoundFailure>());
  });

  test('watchAll re-runs when the profiles table changes', () async {
    final emissions = <List<String>>[];
    // Deliberately not cancelled here: `watchQuery` sits in an `await for` on
    // DbChanges, and cancelling an async* generator parked there only completes
    // once the stream closes — which `changes.dispose()` in tearDown does.
    repository
        .watchAll()
        .listen((profiles) => emissions.add(profiles.map((p) => p.name).toList()));

    await pumpEventQueue();
    await repository.create(name: 'Sara', role: Role.staff, pin: '4321');
    await pumpEventQueue();

    expect(emissions.length, greaterThanOrEqualTo(2));
    expect(emissions.last, contains('Sara'));
  });
}
