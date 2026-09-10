import 'package:sqflite_common/sqlite_api.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/validation.dart';
import '../datasources/category_local_data_source.dart';
import '../mappers/category_mapper.dart';

/// Writes run in one transaction and notify [DbChanges] after it commits, so
/// every caller (use cases, and CSV import in W2) keeps the UI in sync.
class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required this.database,
    required this.dataSource,
    required this.changes,
    required this.session,
    required this.ids,
    required this.clock,
  });

  final AppDatabase database;
  final CategoryLocalDataSource dataSource;
  final DbChanges changes;
  final SessionReader session;
  final IdGenerator ids;
  final Clock clock;

  String? get _storeId => session.store?.id;

  @override
  Stream<List<CategoryNode>> watchTree() =>
      watchQuery(changes, {DbTable.categories, DbTable.products}, () async {
        final storeId = _storeId;
        if (storeId == null) return const <CategoryNode>[];
        return categoryTreeFromRows(await dataSource.tree(storeId));
      });

  @override
  Future<Result<Category>> create(String name, {String? parentId}) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    final validated = CategoryValidation.name(name);
    if (validated case Err<String>(:final failure)) return Err(failure);
    final clean = validated.valueOrNull!;

    return _guard(() async {
      final id = ids.newId();
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<Category>>((txn) async {
        if (parentId != null) {
          final parent = await dataSource.byId(storeId, parentId, txn);
          if (parent == null) return const Err(NotFoundFailure('category'));
          if (parent['parent_id'] != null) {
            return const Err(ValidationFailure(field: 'parentId', code: 'max_depth'));
          }
        }
        if (await dataSource.siblingNameTaken(storeId, parentId, clean, txn: txn)) {
          return const Err(ConflictFailure('name'));
        }
        final siblings = await dataSource.siblings(storeId, parentId, txn);
        await dataSource.insert(
          txn,
          id: id,
          storeId: storeId,
          parentId: parentId,
          name: clean,
          sortOrder: siblings.length,
          nowMs: nowMs,
        );
        return Success(Category(id: id, parentId: parentId, name: clean, sortOrder: siblings.length));
      });
      if (result.isSuccess) changes.notify({DbTable.categories});
      return result;
    });
  }

  @override
  Future<Result<Category>> rename(String id, String name) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    final validated = CategoryValidation.name(name);
    if (validated case Err<String>(:final failure)) return Err(failure);
    final clean = validated.valueOrNull!;

    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<Category>>((txn) async {
        final row = await dataSource.byId(storeId, id, txn);
        if (row == null) return const Err(NotFoundFailure('category'));
        final current = categoryFromRow({
          'id': row['id'],
          'parent_id': row['parent_id'],
          'name': row['name'],
          'sort_order': row['sort_order'],
        });
        if (await dataSource.siblingNameTaken(storeId, current.parentId, clean,
            exceptId: id, txn: txn)) {
          return const Err(ConflictFailure('name'));
        }
        await dataSource.updateFields(txn, id, {'name': clean}, nowMs);
        return Success(current.copyWith(name: clean));
      });
      if (result.isSuccess) changes.notify({DbTable.categories});
      return result;
    });
  }

  @override
  Future<Result<void>> move(String id, {String? parentId, required int sortOrder}) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    if (parentId == id) {
      return const Err(ValidationFailure(field: 'parentId', code: 'self_parent'));
    }

    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<void>>((txn) async {
        final row = await dataSource.byId(storeId, id, txn);
        if (row == null) return const Err(NotFoundFailure('category'));
        if (parentId != null) {
          final parent = await dataSource.byId(storeId, parentId, txn);
          if (parent == null) return const Err(NotFoundFailure('category'));
          if (parent['parent_id'] != null) {
            return const Err(ValidationFailure(field: 'parentId', code: 'max_depth'));
          }
          if (await dataSource.childCount(storeId, id, txn) > 0) {
            return const Err(ValidationFailure(field: 'parentId', code: 'max_depth'));
          }
        }
        final oldParentId = row['parent_id'] as String?;
        if (oldParentId != parentId &&
            await dataSource.siblingNameTaken(storeId, parentId, row['name']! as String,
                exceptId: id, txn: txn)) {
          return const Err(ConflictFailure('name'));
        }
        await dataSource.updateFields(txn, id, {'parent_id': parentId}, nowMs);
        await _resequence(txn, storeId, parentId, moved: id, to: sortOrder, nowMs: nowMs);
        if (oldParentId != parentId) {
          await _resequence(txn, storeId, oldParentId, nowMs: nowMs);
        }
        return ok;
      });
      if (result.isSuccess) changes.notify({DbTable.categories});
      return result;
    });
  }

  @override
  Future<Result<void>> delete(String id, {String? moveProductsTo}) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    if (moveProductsTo == id) {
      return const Err(ValidationFailure(field: 'moveProductsTo', code: 'same_category'));
    }

    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<void>>((txn) async {
        final row = await dataSource.byId(storeId, id, txn);
        if (row == null) return const Err(NotFoundFailure('category'));
        if (await dataSource.childCount(storeId, id, txn) > 0) {
          return const Err(ValidationFailure(field: 'id', code: 'not_empty'));
        }
        final products = await dataSource.productCount(storeId, id, txn);
        if (products > 0) {
          if (moveProductsTo == null) {
            return const Err(ValidationFailure(field: 'id', code: 'not_empty'));
          }
          final target = await dataSource.byId(storeId, moveProductsTo, txn);
          if (target == null) return const Err(NotFoundFailure('category'));
          await dataSource.reassignProducts(txn, storeId, id, moveProductsTo, nowMs);
        }
        await dataSource.softDelete(txn, id, nowMs);
        await _resequence(txn, storeId, row['parent_id'] as String?, nowMs: nowMs);
        return ok;
      });
      if (result.isSuccess) {
        changes.notify({DbTable.categories, DbTable.products});
      }
      return result;
    });
  }

  /// Renumbers `sort_order` of the live children of [parentId] to 0..n-1.
  /// When [moved] is given it is placed at index [to] first.
  Future<void> _resequence(
    DatabaseExecutor txn,
    String storeId,
    String? parentId, {
    String? moved,
    int? to,
    required int nowMs,
  }) async {
    final rows = await dataSource.siblings(storeId, parentId, txn);
    final ordered = [for (final r in rows) r['id']! as String];
    if (moved != null) {
      ordered.remove(moved);
      final index = (to ?? ordered.length).clamp(0, ordered.length);
      ordered.insert(index, moved);
    }
    for (var i = 0; i < ordered.length; i++) {
      await dataSource.updateFields(txn, ordered[i], {'sort_order': i}, nowMs);
    }
  }

  /// Turns any storage error into a [StorageFailure] (rule: never throw across layers).
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() action) async {
    try {
      return await action();
    } on DatabaseException catch (e) {
      return Err(StorageFailure('categories', e));
    } on Object catch (e) {
      return Err(StorageFailure('categories', e));
    }
  }
}
