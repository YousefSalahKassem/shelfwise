import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/pricing.dart';
import '../repositories/pricing_repository.dart';
import '../services/bulk_rule_validation.dart';

/// Old vs. new price for every product a [BulkPriceRule] would touch.
/// Reads only — nothing is written until [ApplyBulkPrices] runs the same rule.
class PreviewBulkPrices {
  const PreviewBulkPrices({required this.repository, required this.session});

  final PricingRepository repository;
  final SessionReader session;

  Future<Result<List<PriceChangePreview>>> call(BulkPriceRule rule) async {
    if (!session.can(Permission.editPrices)) {
      return const Err<List<PriceChangePreview>>(PermissionFailure('editPrices'));
    }
    final invalid = validateBulkRule(
      rule,
      currency: session.store?.currency ?? '',
      requireChange: false,
    );
    if (invalid != null) return Err<List<PriceChangePreview>>(invalid);
    return repository.previewBulk(rule);
  }
}
