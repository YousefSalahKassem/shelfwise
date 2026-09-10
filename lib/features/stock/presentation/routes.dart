// OWNER: A4.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/placeholder_page.dart';
import 'pages/adjust_stock_page.dart';
import 'pages/receive_delivery_page.dart';
import 'pages/stock_page.dart';

/// Paths with arguments that [RoutePaths] (frozen) doesn't spell out.
abstract final class StockRoutes {
  /// Quick adjust opened for a known product (from the product detail screen).
  static String adjustFor(String productId) =>
      '${RoutePaths.stockAdjust}?productId=$productId';
}

FeatureRoutes get stockRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.stock,
          builder: (context, state) => const StockPage(),
        ),
        GoRoute(
          path: RoutePaths.stockReceive,
          builder: (context, state) => const ReceiveDeliveryPage(),
        ),
        GoRoute(
          path: RoutePaths.stockAdjust,
          builder: (context, state) =>
              AdjustStockPage(productId: state.uri.queryParameters['productId']),
        ),
        // Stock count mode is D1 (W4), gated by FeatureFlag.stockCount.
        GoRoute(
          path: RoutePaths.stockCount,
          builder: (context, state) => PlaceholderPage(title: (l) => l.stock_countTitle),
        ),
      ],
    );
