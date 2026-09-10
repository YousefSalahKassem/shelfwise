import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/features/categories/data/datasources/category_local_data_source.dart';
import 'package:shelfwise/features/categories/data/repositories/category_repository_impl.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  test('probe', () async {
    print('open');
    final db = await openTestDatabase();
    await Fixtures.seed(db);
    final changes = DbChanges();
    final repo = CategoryRepositoryImpl(
      database: db,
      dataSource: CategoryLocalDataSource(db),
      changes: changes,
      session: FakeSession.ownerSession,
      ids: SequentialIdGenerator('cat'),
      clock: FixedClock(Fixtures.now),
    );
    final emissions = <int>[];
    print('listen');
    final sub = repo.watchTree().listen((v) { print('emit ${v.length}'); emissions.add(v.length); });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    print('create');
    final r = await repo.create('Bakery');
    print('created $r');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    print('cancel');
    await sub.cancel();
    print('cancelled $emissions');
    await changes.dispose();
    await db.close();
    print('done');
  }, timeout: const Timeout(Duration(seconds: 10)));
}
