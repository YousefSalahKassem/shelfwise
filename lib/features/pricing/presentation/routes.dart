// OWNER: A3. Pricing routes (paths come from RoutePaths; both are owner-only
// through `routePermissions[editPrices]` in core/router/guards.dart).
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/bulk_price_page.dart';
import 'pages/single_price_page.dart';

FeatureRoutes get pricingRoutes => FeatureRoutes(
      shell: [
        // Literal path first: `/prices/bulk` must not be read as a product id.
        GoRoute(
          path: RoutePaths.pricesBulk,
          builder: (context, state) =>
              BulkPricePage(initialIds: state.uri.queryParameters['ids'] ?? ''),
        ),
        GoRoute(
          path: RoutePaths.priceEdit,
          builder: (context, state) =>
              SinglePricePage(productId: state.pathParameters['productId'] ?? ''),
        ),
      ],
    );
