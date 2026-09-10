// OWNER: A1.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/lock_page.dart';
import 'pages/profiles_page.dart';

FeatureRoutes get profilesRoutes => FeatureRoutes(
      fullscreen: [
        GoRoute(path: RoutePaths.lock, builder: (context, state) => const LockPage()),
      ],
      shell: [
        GoRoute(
          path: RoutePaths.settingsProfiles,
          builder: (context, state) => const ProfilesPage(),
        ),
      ],
    );
