import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/brand/brand_providers.dart';
import '../../../../core/database/database_providers.dart';
import '../../../../core/database/db_changes.dart';
import '../../../../core/error/result.dart';
import '../../../../core/session/session_impl.dart';
import '../../../../core/utils/core_providers.dart';
import '../../data/datasources/pricing_local_data_source.dart';
import '../../data/models/pricing_rows.dart';
import '../../data/repositories/pricing_repository_impl.dart';
import '../../domain/entities/pricing.dart';
import '../../domain/repositories/pricing_repository.dart';
import '../../domain/usecases/apply_bulk_prices.dart';
import '../../domain/usecases/get_price_history.dart';
import '../../domain/usecases/get_product_pricing.dart';
import '../../domain/usecases/preview_bulk_prices.dart';
import '../../domain/usecases/update_price.dart';

part 'pricing_providers.g.dart';

@Riverpod(keepAlive: true)
PricingLocalDataSource pricingLocalDataSource(Ref ref) =>
    PricingLocalDataSource(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
PricingRepository pricingRepository(Ref ref) => PricingRepositoryImpl(
      local: ref.watch(pricingLocalDataSourceProvider),
      session: ref.watch(sessionControllerProvider),
      clock: ref.watch(clockProvider),
      ids: ref.watch(idGeneratorProvider),
      changes: ref.watch(dbChangesProvider),
    );

@Riverpod(keepAlive: true)
UpdatePrice updatePrice(Ref ref) => UpdatePrice(
      repository: ref.watch(pricingRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
PreviewBulkPrices previewBulkPrices(Ref ref) => PreviewBulkPrices(
      repository: ref.watch(pricingRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
ApplyBulkPrices applyBulkPrices(Ref ref) => ApplyBulkPrices(
      repository: ref.watch(pricingRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
      analytics: ref.watch(analyticsServiceProvider),
    );

@Riverpod(keepAlive: true)
GetProductPricing getProductPricing(Ref ref) => GetProductPricing(
      repository: ref.watch(pricingRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
GetPriceHistory getPriceHistory(Ref ref) =>
    GetPriceHistory(repository: ref.watch(pricingRepositoryProvider));

/// Current price and cost of one product; refreshes when prices change.
@riverpod
Stream<PriceChangePreview> productPricing(Ref ref, String productId) {
  final usecase = ref.watch(getProductPricingProvider);
  final changes = ref.watch(dbChangesProvider);
  return watchQuery(changes, {DbTable.products}, () async {
    final result = await usecase(productId);
    return switch (result) {
      Success<PriceChangePreview>(:final value) => value,
      Err<PriceChangePreview>(:final failure) => throw failure,
    };
  });
}

/// Categories the bulk screen can target (two levels, catalogue order).
@riverpod
Stream<List<CategoryOptionRow>> pricingCategories(Ref ref) {
  final local = ref.watch(pricingLocalDataSourceProvider);
  final storeId = ref.watch(sessionControllerProvider).store?.id;
  final changes = ref.watch(dbChangesProvider);
  if (storeId == null) return Stream.value(const []);
  return watchQuery(
    changes,
    {DbTable.categories},
    () => local.categories(storeId: storeId),
  );
}

/// Currency every price on these screens is in (store first, brand fallback).
@riverpod
String storeCurrency(Ref ref) =>
    ref.watch(sessionControllerProvider).store?.currency ??
    ref.watch(brandConfigProvider).defaultCurrency;
