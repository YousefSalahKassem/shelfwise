import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/pricing.dart';
import '../repositories/pricing_repository.dart';
import '../services/bulk_rule_validation.dart';
import '../services/price_batch_result.dart';
import '../services/price_calculator.dart';

/// Applies a [BulkPriceRule] to every product in scope in one transaction and
/// logs the `bulk_price_updated` pilot metric.
///
/// [duration] is measured by the screen (open → confirm) because only the UI
/// knows when the owner started; it is the business-plan §9 repricing metric.
class ApplyBulkPrices {
  const ApplyBulkPrices({
    required this.repository,
    required this.session,
    required this.analytics,
  });

  final PricingRepository repository;
  final SessionReader session;
  final AnalyticsService analytics;

  Future<Result<PriceBatchResult>> call(
    BulkPriceRule rule, {
    required Duration duration,
  }) async {
    if (!session.can(Permission.editPrices)) {
      return const Err<PriceBatchResult>(PermissionFailure('editPrices'));
    }
    final invalid = validateBulkRule(rule, currency: session.store?.currency ?? '');
    if (invalid != null) return Err<PriceBatchResult>(invalid);

    final applied = await repository.applyBulk(rule);
    switch (applied) {
      case Err<String>(:final failure):
        return Err<PriceBatchResult>(failure);
      case Success<String>(value: final batchId):
        final rows = await repository.batch(batchId);
        final result = PriceBatchResult(
          batchId: batchId,
          changes: rows.valueOrNull ?? const <PriceChange>[],
        );
        await analytics.log(AppEvent.bulkPriceUpdated, {
          'count': result.count,
          'durationMs': duration.inMilliseconds,
          'mode': rule.adjustment.modeName,
        });
        return Success<PriceBatchResult>(result);
    }
  }
}
