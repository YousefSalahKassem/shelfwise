// OWNER: A4.
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/quantity.dart';
import '../repositories/stock_recorder.dart';

/// Sets the level at which a product counts as low, for one product or for a
/// whole category. Owner only ([Permission.setReorderPoints]).
///
/// Changing a reorder point re-evaluates the product's alert in the same
/// transaction (raising it above the current quantity opens an alert, lowering
/// it resolves one) but never fires a notification: bulk setting a category
/// would otherwise flood the store with them.
class SetReorderPoint {
  const SetReorderPoint({
    required this.recorder,
    required this.session,
    required this.analytics,
  });

  final StockRecorder recorder;
  final SessionReader Function() session;
  final AnalyticsService analytics;

  Future<Result<void>> call(String productId, Quantity reorderPoint) async {
    final denied = _check(reorderPoint);
    if (denied != null) return Err(denied);

    final result = await recorder.setReorderPoint(productId, reorderPoint);
    if (result.isSuccess) {
      await analytics.log(AppEvent.reorderPointSet, {
        'product_id': productId,
        'reorder_point_milli': reorderPoint.milli,
        'scope': 'product',
      });
    }
    return result;
  }

  /// Returns how many products were updated.
  Future<Result<int>> forCategory(
    String categoryId,
    Quantity reorderPoint, {
    bool includeSubcategories = true,
  }) async {
    final denied = _check(reorderPoint);
    if (denied != null) return Err(denied);

    final result = await recorder.setReorderPointForCategory(
      categoryId,
      reorderPoint,
      includeSubcategories: includeSubcategories,
    );
    if (result case Success(:final value)) {
      await analytics.log(AppEvent.reorderPointSet, {
        'category_id': categoryId,
        'reorder_point_milli': reorderPoint.milli,
        'scope': 'category',
        'products': value,
      });
    }
    return result;
  }

  Failure? _check(Quantity reorderPoint) {
    if (!session().can(Permission.setReorderPoints)) {
      return const PermissionFailure('setReorderPoints');
    }
    if (reorderPoint.isNegative) {
      return const ValidationFailure(field: 'reorderPoint', code: 'mustBePositive');
    }
    return null;
  }
}
