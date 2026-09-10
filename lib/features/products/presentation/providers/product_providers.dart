import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/session/session_impl.dart';
import '../../data/product_data_providers.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/archive_product.dart';
import '../../domain/usecases/count_products.dart';
import '../../domain/usecases/create_product.dart';
import '../../domain/usecases/find_product_by_barcode.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/get_product_image.dart';
import '../../domain/usecases/set_product_image.dart';
import '../../domain/usecases/update_product.dart';
import '../../domain/usecases/watch_product_summary.dart';
import '../../domain/usecases/watch_products.dart';

part 'product_providers.g.dart';

// ── Use cases (the only thing the UI is allowed to call) ────────────────────

@Riverpod(keepAlive: true)
WatchProducts watchProducts(Ref ref) => WatchProducts(ref.watch(productRepositoryProvider));

@Riverpod(keepAlive: true)
CountProducts countProducts(Ref ref) => CountProducts(ref.watch(productRepositoryProvider));

@Riverpod(keepAlive: true)
WatchProductSummary watchProductSummary(Ref ref) =>
    WatchProductSummary(ref.watch(productDetailRepositoryProvider));

@Riverpod(keepAlive: true)
GetProduct getProduct(Ref ref) => GetProduct(ref.watch(productRepositoryProvider));

@Riverpod(keepAlive: true)
FindProductByBarcode findProductByBarcode(Ref ref) =>
    FindProductByBarcode(ref.watch(productRepositoryProvider));

@Riverpod(keepAlive: true)
CreateProduct createProduct(Ref ref) => CreateProduct(
      repository: ref.watch(productRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
      analytics: ref.watch(analyticsServiceProvider),
    );

@Riverpod(keepAlive: true)
UpdateProduct updateProduct(Ref ref) => UpdateProduct(
      repository: ref.watch(productRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
ArchiveProduct archiveProduct(Ref ref) => ArchiveProduct(
      repository: ref.watch(productRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
SetProductImage setProductImage(Ref ref) => SetProductImage(
      repository: ref.watch(productRepositoryProvider),
      session: ref.watch(sessionControllerProvider),
    );

@Riverpod(keepAlive: true)
GetProductImage getProductImage(Ref ref) =>
    GetProductImage(ref.watch(productRepositoryProvider));

// ── Queries ────────────────────────────────────────────────────────────────

/// Live list for [query]. Re-emits on every products / stock / categories
/// change (`dbChanges`), so a stock movement updates the badges immediately.
@riverpod
Stream<List<ProductSummary>> productList(Ref ref, ProductQuery query) =>
    ref.watch(watchProductsProvider)(query);

/// Total matches for [query], ignoring paging.
@riverpod
Future<int> productMatchCount(Ref ref, ProductQuery query) async {
  final result = await ref.watch(countProductsProvider)(query);
  return result.fold((count) => count, (failure) => 0);
}

/// One product with its stock, for the detail screen.
@riverpod
Stream<ProductSummary?> productSummary(Ref ref, String productId) =>
    ref.watch(watchProductSummaryProvider)(productId);

/// Thumbnail bytes for a product. Re-reads whenever the product row changes,
/// which is how a newly saved photo appears without a manual refresh.
@riverpod
Future<Uint8List?> productImage(Ref ref, String productId) async {
  ref.watch(productSummaryProvider(productId));
  return ref.watch(getProductImageProvider)(productId);
}

/// One product for the edit form. Errors surface as the `Failure` itself, so
/// `ErrorView` can translate them.
@riverpod
Future<Product> editableProduct(Ref ref, String productId) async {
  final result = await ref.watch(getProductProvider)(productId);
  return result.fold((product) => product, (failure) => throw failure);
}
