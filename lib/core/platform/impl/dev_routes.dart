// OWNER: A5 — debug page to try scanner, notifications and files.
import 'package:go_router/go_router.dart';

import '../../router/feature_routes_contract.dart';
import '../../router/route_paths.dart';
import '../../widgets/placeholder_page.dart';

FeatureRoutes get devPlatformRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.devPlatform,
          builder: (context, state) => PlaceholderPage(title: (l) => l.common_devPlatform),
        ),
      ],
    );
