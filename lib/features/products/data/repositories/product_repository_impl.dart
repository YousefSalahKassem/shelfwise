import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/clock.dart';
import '../../../../core/utils/ids.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_detail_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/validation/product_validation.dart';
import '../datasources/product_local_data_source.dart';
import '../mappers/product_mapper.dart';

/// Writes run in one transaction and notify [DbChanges] after it commits, so
/// list, detail and dashboard refresh whoever performed the write (use cases
/// today, CSV import in W2).
class ProductRepositoryImpl implements ProductRepository, ProductDetailRepository {
  ProductRepositoryImpl({
    required this.database,
    required this.dataSource,
    required this.changes,
    required this.session,
    required this.ids,
    required this.clock,
  });

  final AppDatabase database;
  final ProductLocalDataSource dataSource;
  final DbChanges changes;
  final SessionReader session;
  final IdGenerator ids;
  final Clock clock;

  /// Tables a catalogue query reads.
  static const _readTables = {
    DbTable.products,
    DbTable.productImages,
    DbTable.stockLevels,
    DbTable.categories,
  };

  String? get _storeId => session.store?.id;
  String? get _branchId => session.branch?.id;
  String get _currency => session.store?.currency ?? 'EGP';

  @override
  Stream<List<ProductSummary>> watch(ProductQuery query) =>
      watchQuery(changes, _readTables, () async {
        final storeId = _storeId;
        final branchId = _branchId;
        if (storeId == null || branchId == null) return const <ProductSummary>[];
        final rows = await dataSource.search(
          storeId: storeId,
          branchId: branchId,
          query: query,
        );
        return [for (final row in rows) productSummaryFromRow(row, _currency)];
      });

  @override
  Stream<ProductSummary?> watchSummary(String productId) =>
      watchQuery(changes, _readTables, () async {
        final storeId = _storeId;
        final branchId = _branchId;
        if (storeId == null || branchId == null) return null;
        final row = await dataSource.summaryById(
          storeId: storeId,
          branchId: branchId,
          id: productId,
        );
        return row == null ? null : productSummaryFromRow(row, _currency);
      });

  @override
  Future<Result<int>> count(ProductQuery query) async {
    final storeId = _storeId;
    final branchId = _branchId;
    if (storeId == null || branchId == null) return const Err(NotFoundFailure('store'));
    return _guard(() async => Success(
          await dataSource.count(storeId: storeId, branchId: branchId, query: query),
        ));
  }

  @override
  Future<Result<Product>> getById(String id) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    return _guard(() async {
      final row = await dataSource.byId(storeId, id);
      if (row == null) return Err(NotFoundFailure('product', id));
      return Success(productFromRow(row, _currency));
    });
  }

  @override
  Future<Result<Product?>> findByBarcode(String barcode) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    final code = barcode.trim();
    if (code.isEmpty) return const Success(null);
    return _guard(() async {
      final row = await dataSource.byBarcode(storeId, code);
      return Success(row == null ? null : productFromRow(row, _currency));
    });
  }

  @override
  Future<Result<Product>> create(ProductDraft draft) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    final normalized = ProductValidation.normalize(draft);
    if (normalized case Err<ProductDraft>(:final failure)) return Err(failure);
    final clean = normalized.valueOrNull!;

    return _guard(() async {
      final id = ids.newId();
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<Product>>((txn) async {
        final conflict = await _conflict(txn, storeId, clean);
        if (conflict != null) return Err(conflict);
        await dataSource.insert(
          txn,
          insertValuesFromDraft(id: id, storeId: storeId, draft: clean, nowMs: nowMs),
        );
        final row = await dataSource.byId(storeId, id, txn);
        return Success(productFromRow(row!, _currency));
      });
      if (result.isSuccess) changes.notify({DbTable.products});
      return result;
    });
  }

  @override
  Future<Result<Product>> update(String id, ProductDraft draft) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    final normalized = ProductValidation.normalize(draft);
    if (normalized case Err<ProductDraft>(:final failure)) return Err(failure);
    final clean = normalized.valueOrNull!;

    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<Product>>((txn) async {
        if (await dataSource.byId(storeId, id, txn) == null) {
          return Err(NotFoundFailure('product', id));
        }
        final conflict = await _conflict(txn, storeId, clean, exceptId: id);
        if (conflict != null) return Err(conflict);
        await dataSource.updateFields(txn, id, updateValuesFromDraft(clean), nowMs);
        final row = await dataSource.byId(storeId, id, txn);
        return Success(productFromRow(row!, _currency));
      });
      if (result.isSuccess) changes.notify({DbTable.products});
      return result;
    });
  }

  @override
  Future<Result<void>> setArchived(String id, {required bool archived}) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<void>>((txn) async {
        if (await dataSource.byId(storeId, id, txn) == null) {
          return Err(NotFoundFailure('product', id));
        }
        await dataSource.updateFields(txn, id, {'is_archived': archived ? 1 : 0}, nowMs);
        return ok;
      });
      if (result.isSuccess) changes.notify({DbTable.products});
      return result;
    });
  }

  @override
  Future<Result<void>> setImage(String id, Uint8List? jpegBytes) async {
    final storeId = _storeId;
    if (storeId == null) return const Err(NotFoundFailure('store'));
    return _guard(() async {
      final nowMs = clock.now().epochMs;
      final result = await database.transaction<Result<void>>((txn) async {
        if (await dataSource.byId(storeId, id, txn) == null) {
          return Err(NotFoundFailure('product', id));
        }
        if (jpegBytes == null) {
          await dataSource.deleteImage(txn, id);
        } else {
          await dataSource.upsertImage(txn, id, jpegBytes, 'image/jpeg', nowMs);
        }
        await dataSource.updateFields(txn, id, const {}, nowMs);
        return ok;
      });
      if (result.isSuccess) {
        changes.notify({DbTable.productImages, DbTable.products});
      }
      return result;
    });
  }

  @override
  Future<Uint8List?> image(String id) => dataSource.image(id);

  /// Barcode and SKU are unique per store (the barcode also has a unique index).
  Future<Failure?> _conflict(
    DatabaseExecutor txn,
    String storeId,
    ProductDraft draft, {
    String? exceptId,
  }) async {
    final barcode = draft.barcode;
    if (barcode != null &&
        await dataSource.fieldTaken(txn, storeId, 'barcode', barcode, exceptId: exceptId)) {
      return const ConflictFailure('barcode');
    }
    final sku = draft.sku;
    if (sku != null &&
        await dataSource.fieldTaken(txn, storeId, 'sku', sku, exceptId: exceptId)) {
      return const ConflictFailure('sku');
    }
    return null;
  }

  /// Turns any storage error into a [StorageFailure] — data sources may throw,
  /// repositories may not (TECHNICAL_STRUCTURE §3, rule 4).
  Future<Result<T>> _guard<T>(Future<Result<T>> Function() action) async {
    try {
      return await action();
    } on Object catch (e) {
      return Err(StorageFailure('products', e));
    }
  }
}
