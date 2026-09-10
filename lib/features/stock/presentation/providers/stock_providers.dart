// OWNER: A4. Dependency graph of the stock feature.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/platform/impl/platform_providers.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/settings/effective_locale.dart';
import '../../../../core/utils/core_providers.dart';
import '../../data/datasources/stock_local_data_source.dart';
import '../../data/repositories/stock_repository_impl.dart';
import '../../domain/entities/stock.dart';
import '../../domain/entities/stock_view.dart';
import '../../domain/repositories/stock_recorder.dart';
import '../../domain/usecases/get_stock.dart';
import '../../domain/usecases/record_stock_movement.dart';
import '../../domain/usecases/set_reorder_point.dart';
import '../widgets/movement_labels.dart';

part 'stock_providers.g.dart';

@Riverpod(keepAlive: true)
StockLocalDataSource stockLocalDataSource(Ref ref) => StockLocalDataSource(
      ref.watch(appDatabaseProvider),
      ref.watch(clockProvider),
      ref.watch(idGeneratorProvider),
    );

@Riverpod(keepAlive: true)
StockRecorder stockRepository(Ref ref) => StockRepositoryImpl(
      local: ref.watch(stockLocalDataSourceProvider),
      changes: ref.watch(dbChangesProvider),
      session: () => ref.read(sessionControllerProvider),
    );

/// Quantity as it appears in a low-stock notification, e.g. `2 kg`.
@Riverpod(keepAlive: true)
QuantityLabel quantityLabel(Ref ref) {
  final formatters = ref.watch(appFormattersProvider);
  final l10n = lookupAppLocalizations(ref.watch(effectiveLocaleProvider));
  return (quantity, unit) => '${formatters.quantity(quantity)} ${unitLabel(l10n, unit)}';
}

@Riverpod(keepAlive: true)
RecordStockMovement recordStockMovement(Ref ref) => RecordStockMovement(
      recorder: ref.watch(stockRepositoryProvider),
      session: () => ref.read(sessionControllerProvider),
      notifications: ref.watch(notificationServiceProvider),
      analytics: ref.watch(analyticsServiceProvider),
      quantityLabel: ref.watch(quantityLabelProvider),
    );

@Riverpod(keepAlive: true)
SetReorderPoint setReorderPoint(Ref ref) => SetReorderPoint(
      recorder: ref.watch(stockRepositoryProvider),
      session: () => ref.read(sessionControllerProvider),
      analytics: ref.watch(analyticsServiceProvider),
    );

@Riverpod(keepAlive: true)
GetStock getStock(Ref ref) => GetStock(
      recorder: ref.watch(stockRepositoryProvider),
      session: () => ref.read(sessionControllerProvider),
    );

/// Re-runs [query] whenever one of [tables] changes; a [Failure] becomes an
/// `AsyncValue.error` the UI renders with `ErrorView`.
Stream<T> watchResult<T>(Ref ref, Set<DbTable> tables, Future<Result<T>> Function() query) =>
    watchQuery(ref.watch(dbChangesProvider), tables, () async {
      final result = await query();
      return switch (result) {
        Success<T>(:final value) => value,
        Err<T>(:final failure) => throw failure,
      };
    });

/// Current level and reorder point of one product.
@riverpod
Stream<StockLevel> stockLevel(Ref ref, String productId) =>
    ref.watch(getStockProvider).watchLevel(productId);

/// Product name, unit and stock — the header of the stock screens.
@riverpod
Stream<ProductStock> productStock(Ref ref, String productId) => watchResult(
      ref,
      {DbTable.stockLevels, DbTable.products},
      () => ref.read(getStockProvider).productStock(productId),
    );

/// Ledger of one product, newest first.
@riverpod
Stream<List<MovementEntry>> productMovements(Ref ref, String productId) => watchResult(
      ref,
      {DbTable.stockMovements},
      () => ref.read(getStockProvider).history(productId),
    );

/// Latest movements across the branch.
@riverpod
Stream<List<MovementEntry>> recentMovements(Ref ref, {int limit = 20}) => watchResult(
      ref,
      {DbTable.stockMovements},
      () => ref.read(getStockProvider).recent(limit: limit),
    );
