import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/auth/permission.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_reader.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';
import '../validation/product_validation.dart';

/// Adds a product to the catalogue. Price and cost are the *initial* values —
/// later changes go through pricing (A3), which owns those columns.
///
/// The catalogue is in every tier, so there is no feature flag to check.
class CreateProduct {
  const CreateProduct({
    required this.repository,
    required this.session,
    required this.analytics,
  });

  final ProductRepository repository;
  final SessionReader session;
  final AnalyticsService analytics;

  Future<Result<Product>> call(ProductDraft draft) async {
    if (!session.can(Permission.editCatalogue)) {
      return const Err(PermissionFailure('editCatalogue'));
    }
    final normalized = ProductValidation.normalize(draft);
    if (normalized case Err<ProductDraft>(:final failure)) return Err(failure);

    final result = await repository.create(normalized.valueOrNull!);
    if (result case Success<Product>(:final value)) {
      await analytics.log(AppEvent.productCreated, {
        'productId': value.id,
        'hasBarcode': value.barcode != null,
        'hasCategory': value.categoryId != null,
        'unit': value.unit.name,
      });
    }
    return result;
  }
}
