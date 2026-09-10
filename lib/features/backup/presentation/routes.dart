// OWNER: feature agent (see AGENT_PHASES §5). W0 stub — replace freely.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/widgets/placeholder_page.dart';

FeatureRoutes get backupRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.settingsBackup,
          builder: (context, state) => PlaceholderPage(title: (l) => l.backup_title),
        ),
      ],
    );
