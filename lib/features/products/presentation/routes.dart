// OWNER: feature agent (see AGENT_PHASES §5). W0 stub — replace freely.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/placeholder_page.dart';

FeatureRoutes get productsRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.products,
          builder: (context, state) => PlaceholderPage(title: (l) => l.catalogue_productsTitle),
        ),
        GoRoute(
          path: RoutePaths.productNew,
          builder: (context, state) => PlaceholderPage(title: (l) => l.catalogue_newProductTitle),
        ),
        GoRoute(
          path: RoutePaths.productEdit,
          builder: (context, state) => PlaceholderPage(title: (l) => l.catalogue_editProductTitle),
        ),
        GoRoute(
          path: RoutePaths.productDetail,
          builder: (context, state) => PlaceholderPage(title: (l) => l.catalogue_productTitle),
        ),
      ],
    );
