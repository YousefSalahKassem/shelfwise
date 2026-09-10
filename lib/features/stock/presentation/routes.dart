// OWNER: feature agent (see AGENT_PHASES §5). W0 stub — replace freely.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/placeholder_page.dart';

FeatureRoutes get stockRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.stock,
          builder: (context, state) => PlaceholderPage(title: (l) => l.stock_title),
        ),
        GoRoute(
          path: RoutePaths.stockReceive,
          builder: (context, state) => PlaceholderPage(title: (l) => l.stock_receiveTitle),
        ),
        GoRoute(
          path: RoutePaths.stockAdjust,
          builder: (context, state) => PlaceholderPage(title: (l) => l.stock_adjustTitle),
        ),
        GoRoute(
          path: RoutePaths.stockCount,
          builder: (context, state) => PlaceholderPage(title: (l) => l.stock_countTitle),
        ),
      ],
    );
