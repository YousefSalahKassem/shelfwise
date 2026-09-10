// OWNER: A4.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/alerts_page.dart';

FeatureRoutes get alertsRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.alerts,
          builder: (context, state) => const AlertsPage(),
        ),
      ],
    );
