// OWNER: A4.
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/domain/stock_status.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/platform/notification_service.dart';
import '../../../../core/session/session_reader.dart';
import '../../../../core/utils/quantity.dart';
import '../entities/stock.dart';
import '../entities/stock_view.dart';
import '../repositories/stock_recorder.dart';

/// Renders a quantity for a notification body, e.g. `2 kg`. Injected so the
/// domain stays free of Flutter and l10n.
typedef QuantityLabel = String Function(Quantity quantity, ProductUnit unit);

String defaultQuantityLabel(Quantity quantity, ProductUnit unit) =>
    quantity.toDecimalString();

/// Records one or more stock movements. Everything the store does to stock —
/// receiving, selling, damage, expiry, corrections — goes through here so the
/// ledger, the cached level and the alerts can never drift apart.
///
/// One transaction (in the repository): ledger row → level upsert → alert
/// evaluation. After the commit: one local notification per newly opened alert
/// plus the pilot events.
class RecordStockMovement {
  const RecordStockMovement({
    required this.recorder,
    required this.session,
    required this.notifications,
    required this.analytics,
    this.quantityLabel = defaultQuantityLabel,
  });

  final StockRecorder recorder;
  final SessionReader Function() session;
  final NotificationService notifications;
  final AnalyticsService analytics;
  final QuantityLabel quantityLabel;

  /// Maximum length of a movement note.
  static const int maxNoteLength = 500;

  Future<Result<StockMovement>> call(MovementInput input) async {
    final result = await many([input]);
    return result.map((batch) => batch.movements.first);
  }

  /// Several lines committed together (receive delivery, CSV import).
  Future<Result<MovementBatch>> many(List<MovementInput> inputs) async {
    if (inputs.isEmpty) {
      return const Err(ValidationFailure(field: 'lines', code: 'empty'));
    }
    final current = session();
    for (final input in inputs) {
      final permission = permissionFor(input.type);
      if (!current.can(permission)) return Err(PermissionFailure(permission.name));
      final invalid = validate(input);
      if (invalid != null) return Err(invalid);
    }

    final result = await recorder.recordBatch(inputs);
    if (result case Err(:final failure)) return Err(failure);
    final batch = result.valueOrNull!;

    for (final movement in batch.movements) {
      await analytics.log(AppEvent.stockMovementRecorded, {
        'type': movement.type.dbName,
        'product_id': movement.productId,
        'qty_delta_milli': movement.delta.milli,
      });
    }
    for (final alert in batch.openedAlerts) {
      await analytics.log(AppEvent.lowStockAlertFired, {
        'product_id': alert.productId,
        'level': alert.level.name,
        'qty_milli': alert.quantity.milli,
      });
      await notifications.showLowStock(
        LowStockNotice(
          productId: alert.productId,
          productName: alert.productName,
          level: alert.level,
          quantityText: quantityLabel(alert.quantity, alert.unit),
        ),
      );
    }
    return Success(batch);
  }

  /// Staff may receive and adjust stock (business plan): corrections need
  /// [Permission.adjustStock], everything else [Permission.recordStock].
  static Permission permissionFor(MovementType type) => switch (type) {
        MovementType.adjustment || MovementType.count => Permission.adjustStock,
        _ => Permission.recordStock,
      };

  /// Null when [input] is valid. Whether the resulting level may go negative is
  /// re-checked inside the transaction, where the current level is known.
  static ValidationFailure? validate(MovementInput input) {
    if (input.quantity.isZero) {
      return const ValidationFailure(field: 'quantity', code: 'required');
    }
    if (input.type.sign != 0 && input.quantity.isNegative) {
      return const ValidationFailure(field: 'quantity', code: 'mustBePositive');
    }
    if (input.unitCost != null && input.unitCost!.isNegative) {
      return const ValidationFailure(field: 'unitCost', code: 'mustBePositive');
    }
    if ((input.note?.length ?? 0) > maxNoteLength) {
      return const ValidationFailure(field: 'note', code: 'tooLong');
    }
    return null;
  }

  /// Signed change this input applies to the level.
  static Quantity deltaOf(MovementInput input) => input.type.sign == 0
      ? input.quantity
      : Quantity(input.type.sign * input.quantity.milli);

  /// Status a product reaches at [quantity]; used for previews before saving.
  static StockStatus statusFor(Quantity quantity, Quantity reorderPoint) =>
      StockStatus.of(qtyMilli: quantity.milli, reorderPointMilli: reorderPoint.milli);
}
