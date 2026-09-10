import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/migrations/migration.dart';
import 'package:shelfwise/core/database/schema/tables.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() async => db = await openTestDatabase());
  tearDown(() => db.close());

  test('creates schema v1 with every table', () async {
    expect(await db.schemaVersion, latestSchemaVersion);
    final rows = await db.db.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final names = rows.map((r) => r['name']).toSet();
    for (final t in [
      T.stores, T.branches, T.profiles, T.categories, T.products, T.productImages,
      T.stockLevels, T.stockMovements, T.priceChanges, T.stockAlerts, T.appEvents, T.settings,
    ]) {
      expect(names, contains(t));
    }
  });

  test('foreign keys are enforced', () async {
    final fk = await db.db.rawQuery('PRAGMA foreign_keys');
    expect(fk.first.values.first, 1);
    expect(
      () => db.db.insert(T.branches, {
        C.id: 'b', C.storeId: 'missing', 'name': 'x', C.createdAt: 0, C.updatedAt: 0,
      }),
      throwsA(anything),
    );
  });

  test('fixtures seed cleanly', () async {
    await Fixtures.seed(db);
    final count = await db.db.rawQuery('SELECT COUNT(*) AS n FROM ${T.products}');
    expect(count.first['n'], 20);
  });

  test('barcode is unique per store', () async {
    await Fixtures.seed(db);
    expect(
      () => db.db.insert(T.products, {
        C.id: 'dup', C.storeId: 'store-1', 'name': 'Dup', 'barcode': '6220000000001',
        'price_minor': 1, C.createdAt: 0, C.updatedAt: 0,
      }),
      throwsA(anything),
    );
  });

  test('check constraints reject unknown movement types', () async {
    await Fixtures.seed(db);
    expect(
      () => db.db.insert(T.stockMovements, {
        C.id: 'm1', C.productId: 'prod-1', C.branchId: 'branch-1', 'type': 'stolen',
        'qty_delta_milli': -1000, 'qty_after_milli': 0, C.profileId: 'profile-owner',
        C.createdAt: 0, C.updatedAt: 0,
      }),
      throwsA(anything),
    );
  });
}
