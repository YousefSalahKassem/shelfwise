import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/auth/permission.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/features/onboarding/data/datasources/store_local_data_source.dart';
import 'package:shelfwise/features/onboarding/data/repositories/store_repository_impl.dart';
import 'package:shelfwise/features/profiles/domain/services/pin_hasher.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/test_db.dart';

void main() {
  const hasher = PinHasher(iterations: 100);

  late AppDatabase db;
  late DbChanges changes;
  late StoreRepositoryImpl repository;

  setUp(() async {
    db = await openTestDatabase();
    changes = DbChanges();
    repository = StoreRepositoryImpl(
      local: StoreLocalDataSource(
        db: db,
        clock: FixedClock(Fixtures.now),
        ids: SequentialIdGenerator(),
        hasher: hasher,
      ),
      changes: changes,
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  test('there is no store before onboarding', () async {
    expect((await repository.getCurrent()).valueOrNull, isNull);
    expect((await repository.getDefaultBranch()).valueOrNull, isNull);
  });

  test('creates store, default branch and owner in one transaction', () async {
    final tables = <Set<DbTable>>[];
    changes.watch(DbTable.values.toSet()).listen(tables.add);

    final setup = (await repository.createStoreWithOwner(
      storeName: 'Al Nour Market',
      currency: 'EGP',
      locale: 'ar',
      ownerName: 'Karim',
      pin: '482913',
    ))
        .valueOrNull!;

    expect(setup.store.name, 'Al Nour Market');
    expect(setup.branch.storeId, setup.store.id);
    expect(setup.branch.isDefault, isTrue);
    expect(setup.owner.role, Role.owner);
    expect(setup.owner.locale, 'ar');

    expect((await db.db.query(T.stores)).length, 1);
    expect((await db.db.query(T.branches)).length, 1);
    expect((await db.db.query(T.profiles)).length, 1);

    await pumpEventQueue();
    expect(tables.single, containsAll([DbTable.stores, DbTable.branches, DbTable.profiles]));
  });

  test('the owner PIN is stored salted and hashed, never in clear text', () async {
    await repository.createStoreWithOwner(
      storeName: 'Al Nour Market',
      currency: 'EGP',
      locale: 'en',
      ownerName: 'Karim',
      pin: '482913',
    );

    final row = (await db.db.query(T.profiles)).single;
    final hash = row['pin_hash']! as String;
    final salt = row['pin_salt']! as String;

    expect(hash, isNot(contains('482913')));
    expect(salt, isNotEmpty);
    expect(hasher.verify(pin: '482913', hash: hash, salt: salt), isTrue);
    expect(hasher.verify(pin: '482914', hash: hash, salt: salt), isFalse);
  });

  test('reads the store and default branch back', () async {
    final setup = (await repository.createStoreWithOwner(
      storeName: 'Al Nour Market',
      currency: 'SAR',
      locale: 'ar',
      ownerName: 'Karim',
      pin: '1234',
    ))
        .valueOrNull!;

    expect((await repository.getCurrent()).valueOrNull, setup.store);
    expect((await repository.getDefaultBranch()).valueOrNull, setup.branch);
  });

  test('a second store on the same device is a conflict', () async {
    await repository.createStoreWithOwner(
      storeName: 'First',
      currency: 'EGP',
      locale: 'en',
      ownerName: 'Karim',
      pin: '1234',
    );
    final again = await repository.createStoreWithOwner(
      storeName: 'Second',
      currency: 'EGP',
      locale: 'en',
      ownerName: 'Mona',
      pin: '1234',
    );

    expect(again.failureOrNull, isA<ConflictFailure>());
    expect((await db.db.query(T.stores)).length, 1);
  });

  test('updates the store name and currency', () async {
    await repository.createStoreWithOwner(
      storeName: 'Al Nour Market',
      currency: 'EGP',
      locale: 'en',
      ownerName: 'Karim',
      pin: '1234',
    );

    final updated = (await repository.updateStore(name: 'Nour Express', currency: 'SAR')).valueOrNull!;

    expect(updated.name, 'Nour Express');
    expect(updated.currency, 'SAR');
    expect((await repository.getCurrent()).valueOrNull?.name, 'Nour Express');
  });

  test('updating without a store reports not found', () async {
    final result = await repository.updateStore(name: 'Nope', currency: 'EGP');
    expect(result.failureOrNull, isA<NotFoundFailure>());
  });
}
