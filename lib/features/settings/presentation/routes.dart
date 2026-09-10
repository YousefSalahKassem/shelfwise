// OWNER: A1.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/settings_page.dart';

FeatureRoutes get settingsRoutes => FeatureRoutes(
      shell: [
        GoRoute(path: RoutePaths.settings, builder: (context, state) => const SettingsPage()),
      ],
    );
