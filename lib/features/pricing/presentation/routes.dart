// OWNER: feature agent (see AGENT_PHASES §5). W0 stub — replace freely.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/placeholder_page.dart';

FeatureRoutes get pricingRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.pricesBulk,
          builder: (context, state) => PlaceholderPage(title: (l) => l.pricing_bulkTitle),
        ),
        GoRoute(
          path: RoutePaths.priceEdit,
          builder: (context, state) => PlaceholderPage(title: (l) => l.pricing_editTitle),
        ),
      ],
    );
