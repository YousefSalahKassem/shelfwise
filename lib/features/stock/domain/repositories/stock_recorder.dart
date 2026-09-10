// OWNER: A4. Internal extension of the frozen [StockRepository] contract.
//
// `StockRepository.record` returns only the ledger row, but the use case has to
// know which alerts the transaction opened so it can fire one notification per
// new alert *after* the commit. [StockRecorder] adds that without touching the
// frozen interface: other features keep using [StockRepository].
import '../../../../core/error/result.dart';
import '../../../../core/utils/date_range.dart';
import '../entities/stock.dart';
import '../entities/stock_view.dart';
import 'stock_repository.dart';

abstract interface class StockRecorder implements StockRepository {
  /// Ledger rows + level upserts + alert evaluation for every input, in one
  /// transaction. Nothing is written when any input fails.
  Future<Result<MovementBatch>> recordBatch(List<MovementInput> inputs);

  /// Current stock of [productId] at the session branch.
  Future<Result<ProductStock>> productStock(String productId);

  /// Product with this exact barcode or SKU, for the scan-first flows.
  /// Success(null) when nothing matches.
  Future<Result<ProductStock?>> findByCode(String code);

  /// Latest movements across all products at the session branch.
  Future<Result<List<MovementEntry>>> recentMovements({int limit = 20});

  /// Movements of one product with the product name attached.
  Future<Result<List<MovementEntry>>> movementEntries(
    String productId, {
    DateRange? range,
    int limit = 100,
  });
}
