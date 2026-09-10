// OWNER: A1.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/onboarding_page.dart';

FeatureRoutes get onboardingRoutes => FeatureRoutes(
      fullscreen: [
        GoRoute(
          path: RoutePaths.onboarding,
          builder: (context, state) => const OnboardingPage(),
        ),
      ],
    );
