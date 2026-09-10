import '../../../../core/error/result.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/quantity.dart';
import '../entities/stock.dart';

abstract interface class StockRepository {
  /// Current branch level (zero if never stocked).
  Stream<StockLevel> watchLevel(String productId);

  /// Ledger + level + alert in one transaction (see A4 brief).
  Future<Result<StockMovement>> record(MovementInput input);

  /// Several movements in one transaction (receive delivery, imports).
  Future<Result<List<StockMovement>>> recordMany(List<MovementInput> inputs);

  Future<Result<List<StockMovement>>> movements(String productId, {DateRange? range, int limit = 100});

  Future<Result<void>> setReorderPoint(String productId, Quantity reorderPoint);

  Future<Result<int>> setReorderPointForCategory(String categoryId, Quantity reorderPoint,
      {bool includeSubcategories = true});
}
