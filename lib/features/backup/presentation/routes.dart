// OWNER: A6.
import 'package:go_router/go_router.dart';

import '../../../core/router/feature_routes_contract.dart';
import '../../../core/router/route_paths.dart';
import 'pages/backup_page.dart';

/// Guarded by `Permission.backupRestore` in `core/router/guards.dart`, so a
/// staff profile can't reach it by typing the URL either.
FeatureRoutes get backupRoutes => FeatureRoutes(
      shell: [
        GoRoute(
          path: RoutePaths.settingsBackup,
          builder: (context, state) => const BackupPage(),
        ),
      ],
    );
