import 'package:flutter_test/flutter_test.dart';
import 'package:shelfwise/core/database/app_database.dart';
import 'package:shelfwise/core/database/db_changes.dart';
import 'package:shelfwise/core/database/schema/tables.dart';
import 'package:shelfwise/core/error/failure.dart';
import 'package:shelfwise/core/session/fake_session.dart';
import 'package:shelfwise/core/utils/clock.dart';
import 'package:shelfwise/core/utils/ids.dart';
import 'package:shelfwise/features/categories/data/datasources/category_local_data_source.dart';
import 'package:shelfwise/features/categories/data/repositories/category_repository_impl.dart';
import 'package:shelfwise/features/categories/domain/entities/category.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/test_db.dart';

void main() {
  late AppDatabase db;
  late DbChanges changes;
  late CategoryRepositoryImpl repository;

  setUp(() async {
    db = await openTestDatabase();
    await Fixtures.seed(db);
    changes = DbChanges();
    repository = CategoryRepositoryImpl(
      database: db,
      dataSource: CategoryLocalDataSource(db),
      changes: changes,
      session: FakeSession.ownerSession,
      ids: SequentialIdGenerator('cat'),
      clock: FixedClock(Fixtures.now),
    );
  });

  tearDown(() async {
    await changes.dispose();
    await db.close();
  });

  Future<List<CategoryNode>> tree() => repository.watchTree().first;

  group('tree', () {
    test('groups children under their parent with product counts', () async {
      final nodes = await tree();
      expect(nodes.map((n) => n.category.name), ['Dairy', 'Drinks']);

      final dairy = nodes.first;
      expect(dairy.children.map((c) => c.name), ['Cheese']);
      expect(dairy.productCount, 6);
      expect(nodes.last.productCount, 7);
    });

    test('re-emits after a write', () async {
      final emissions = <List<CategoryNode>>[];
      final sub = repository.watchTree().listen(emissions.add);
      await pumpEventQueue();

      await repository.create('Bakery');
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.length, 2);
      expect(emissions.last.map((n) => n.category.name), ['Dairy', 'Drinks', 'Bakery']);
    });
  });

  group('create', () {
    test('adds a top-level category at the end', () async {
      final result = await repository.create('Bakery');
      expect(result.valueOrNull?.name, 'Bakery');
      expect(result.valueOrNull?.sortOrder, 2);
    });

    test('adds a sub-category under a top-level parent', () async {
      final result = await repository.create('Yoghurt', parentId: 'cat-dairy');
      expect(result.isSuccess, isTrue);
      final dairy = (await tree()).first;
      expect(dairy.children.map((c) => c.name), ['Cheese', 'Yoghurt']);
    });

    test('refuses a third level', () async {
      final result = await repository.create('Feta', parentId: 'cat-cheese');
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect((result.failureOrNull! as ValidationFailure).code, 'max_depth');
    });

    test('refuses a duplicate name among siblings', () async {
      final result = await repository.create('drinks');
      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('allows the same name under a different parent', () async {
      final result = await repository.create('Drinks', parentId: 'cat-dairy');
      expect(result.isSuccess, isTrue);
    });

    test('reports a missing parent', () async {
      final result = await repository.create('Ghost', parentId: 'nope');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('rename', () {
    test('changes the name', () async {
      final result = await repository.rename('cat-drinks', 'Beverages');
      expect(result.valueOrNull?.name, 'Beverages');
      expect((await tree()).last.category.name, 'Beverages');
    });

    test('refuses a name another sibling already uses', () async {
      final result = await repository.rename('cat-drinks', 'Dairy');
      expect(result.failureOrNull, isA<ConflictFailure>());
    });

    test('keeps its own name (renaming to itself is allowed)', () async {
      expect((await repository.rename('cat-drinks', 'Drinks')).isSuccess, isTrue);
    });
  });

  group('move', () {
    test('promotes a sub-category to the top level', () async {
      final result = await repository.move('cat-cheese', sortOrder: 0);
      expect(result.isSuccess, isTrue);
      final nodes = await tree();
      expect(nodes.map((n) => n.category.name), ['Cheese', 'Dairy', 'Drinks']);
      expect(nodes.first.children, isEmpty);
    });

    test('reorders siblings', () async {
      final result = await repository.move('cat-drinks', sortOrder: 0);
      expect(result.isSuccess, isTrue);
      expect((await tree()).map((n) => n.category.name), ['Drinks', 'Dairy']);
    });

    test('refuses to move a category that has children under a parent', () async {
      final result = await repository.move('cat-dairy', parentId: 'cat-drinks', sortOrder: 0);
      expect((result.failureOrNull! as ValidationFailure).code, 'max_depth');
    });

    test('refuses to move a category under a sub-category', () async {
      final result = await repository.move('cat-drinks', parentId: 'cat-cheese', sortOrder: 0);
      expect((result.failureOrNull! as ValidationFailure).code, 'max_depth');
    });

    test('refuses to make a category its own parent', () async {
      final result = await repository.move('cat-drinks', parentId: 'cat-drinks', sortOrder: 0);
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('moves a childless top-level category under another one', () async {
      await repository.create('Bakery');
      final bakery = (await tree()).last.category;
      final result = await repository.move(bakery.id, parentId: 'cat-drinks', sortOrder: 0);
      expect(result.isSuccess, isTrue);
      expect((await tree()).last.children.map((c) => c.name), ['Bakery']);
    });
  });

  group('delete', () {
    test('refuses while it still has sub-categories', () async {
      final result = await repository.delete('cat-dairy');
      expect((result.failureOrNull! as ValidationFailure).code, 'not_empty');
    });

    test('refuses while it still has products', () async {
      final result = await repository.delete('cat-cheese');
      expect((result.failureOrNull! as ValidationFailure).code, 'not_empty');
    });

    test('moves the products first when a target is given', () async {
      final result = await repository.delete('cat-cheese', moveProductsTo: 'cat-drinks');
      expect(result.isSuccess, isTrue);

      final nodes = await tree();
      expect(nodes.map((n) => n.category.name), ['Dairy', 'Drinks']);
      expect(nodes.first.children, isEmpty);
      expect(nodes.last.productCount, 14);
    });

    test('soft-deletes rather than dropping the row', () async {
      await repository.create('Bakery');
      final bakery = (await tree()).last.category;
      expect((await repository.delete(bakery.id)).isSuccess, isTrue);

      final rows = await db.db.query(
        T.categories,
        where: '${C.id} = ?',
        whereArgs: [bakery.id],
      );
      expect(rows.single[C.deletedAt], isNotNull);
      expect((await tree()).map((n) => n.category.name), ['Dairy', 'Drinks']);
    });

    test('refuses to move products into the category being deleted', () async {
      final result = await repository.delete('cat-cheese', moveProductsTo: 'cat-cheese');
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}
