// OWNER: A4. Read-side use cases for the stock screens.
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/date_range.dart';
import '../entities/stock.dart';
import '../entities/stock_view.dart';
import '../repositories/stock_recorder.dart';

/// Stock reads. Everyone who may see the catalogue may see its stock
/// (TECHNICAL_STRUCTURE §10), so one permission covers all of them.
class GetStock {
  const GetStock({required this.recorder, required this.session});

  final StockRecorder recorder;
  final SessionReader Function() session;

  bool get _allowed => session().can(Permission.viewCatalogue);

  static const Failure _denied = PermissionFailure('viewCatalogue');

  /// Current quantity and reorder point of a product at the session branch.
  Future<Result<ProductStock>> productStock(String productId) async =>
      _allowed ? recorder.productStock(productId) : const Err(_denied);

  /// Live level of one product (product detail, adjust screen).
  Stream<StockLevel> watchLevel(String productId) => recorder.watchLevel(productId);

  /// Ledger of one product, newest first.
  Future<Result<List<MovementEntry>>> history(
    String productId, {
    DateRange? range,
    int limit = 100,
  }) async =>
      _allowed
          ? recorder.movementEntries(productId, range: range, limit: limit)
          : const Err(_denied);

  /// Latest movements across the branch (stock overview screen).
  Future<Result<List<MovementEntry>>> recent({int limit = 20}) async =>
      _allowed ? recorder.recentMovements(limit: limit) : const Err(_denied);

  /// Product behind a scanned barcode or typed SKU. Success(null) = no match.
  Future<Result<ProductStock?>> findByCode(String code) async =>
      _allowed ? recorder.findByCode(code) : const Err(_denied);
}
