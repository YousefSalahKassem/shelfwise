// OWNER: A4.
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/quantity.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';
import '../../domain/repositories/stock_recorder.dart';
import '../datasources/stock_local_data_source.dart';
import '../models/stock_rows.dart';

/// Implements the frozen [StockRepository] plus the A4-internal [StockRecorder].
/// Turns exceptions into [Failure]s and announces committed writes on
/// [DbChanges] so every query provider refreshes.
class StockRepositoryImpl implements StockRecorder {
  const StockRepositoryImpl({
    required this.local,
    required this.changes,
    required this.session,
  });

  final StockLocalDataSource local;
  final DbChanges changes;
  final SessionReader Function() session;

  static const _writtenTables = {
    DbTable.stockMovements,
    DbTable.stockLevels,
    DbTable.stockAlerts,
  };

  StockScope? get _scope {
    final current = session();
    final store = current.store;
    final branch = current.branch;
    final profile = current.profile;
    if (store == null || branch == null || profile == null) return null;
    return StockScope(
      storeId: store.id,
      branchId: branch.id,
      profileId: profile.id,
      currency: store.currency,
    );
  }

  Future<Result<T>> _guard<T>(Future<T> Function(StockScope scope) action) async {
    final scope = _scope;
    if (scope == null) return const Err(NotFoundFailure('session'));
    try {
      return Success(await action(scope));
    } on StockDataException catch (e) {
      return Err(e.failure);
    } on Object catch (e) {
      return Err(StorageFailure('stock write failed', e));
    }
  }

  @override
  Future<Result<MovementBatch>> recordBatch(List<MovementInput> inputs) async {
    final result = await _guard((scope) => local.recordBatch(inputs, scope));
    if (result.isSuccess) changes.notify(_writtenTables);
    return result;
  }

  @override
  Future<Result<StockMovement>> record(MovementInput input) async =>
      (await recordBatch([input])).map((batch) => batch.movements.first);

  @override
  Future<Result<List<StockMovement>>> recordMany(List<MovementInput> inputs) async =>
      (await recordBatch(inputs)).map((batch) => batch.movements);

  @override
  Future<Result<void>> setReorderPoint(String productId, Quantity reorderPoint) async {
    final result =
        await _guard((scope) => local.setReorderPoint(productId, reorderPoint, scope));
    if (result.isSuccess) {
      changes.notify({DbTable.products, DbTable.stockAlerts});
    }
    return result;
  }

  @override
  Future<Result<int>> setReorderPointForCategory(
    String categoryId,
    Quantity reorderPoint, {
    bool includeSubcategories = true,
  }) async {
    final result = await _guard(
      (scope) => local.setReorderPointForCategory(
        categoryId,
        reorderPoint,
        scope,
        includeSubcategories: includeSubcategories,
      ),
    );
    if (result.isSuccess) {
      changes.notify({DbTable.products, DbTable.stockAlerts});
    }
    return result;
  }

  @override
  Stream<StockLevel> watchLevel(String productId) {
    final scope = _scope;
    if (scope == null) return const Stream.empty();
    return watchQuery(
      changes,
      {DbTable.stockLevels, DbTable.products},
      () => local.level(productId, scope),
    );
  }

  @override
  Future<Result<ProductStock>> productStock(String productId) =>
      _guard((scope) => local.productStock(productId, scope));

  @override
  Future<Result<ProductStock?>> findByCode(String code) =>
      _guard((scope) => local.findByCode(code, scope));

  @override
  Future<Result<List<MovementEntry>>> recentMovements({int limit = 20}) =>
      _guard((scope) => local.recentMovements(scope, limit: limit));

  @override
  Future<Result<List<MovementEntry>>> movementEntries(
    String productId, {
    DateRange? range,
    int limit = 100,
  }) =>
      _guard((scope) => local.movements(productId, scope, range: range, limit: limit));

  @override
  Future<Result<List<StockMovement>>> movements(
    String productId, {
    DateRange? range,
    int limit = 100,
  }) async =>
      (await movementEntries(productId, range: range, limit: limit))
          .map((entries) => [for (final e in entries) e.movement]);
}
