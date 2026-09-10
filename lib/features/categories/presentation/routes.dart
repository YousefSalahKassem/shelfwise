// OWNER: A2.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/categories_page.dart';

FeatureRoutes get categoriesRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.categories,
          builder: (context, state) => const CategoriesPage(),
        ),
      ],
    );
