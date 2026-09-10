// OWNER: lead. Written once in W0 — features change their own routes.dart only.
import '../../features/alerts/presentation/routes.dart';
import '../../features/backup/presentation/routes.dart';
import '../../features/categories/presentation/routes.dart';
import '../../features/dashboard/presentation/routes.dart';
import '../../features/import_export/presentation/routes.dart';
import '../../features/onboarding/presentation/routes.dart';
import '../../features/pricing/presentation/routes.dart';
import '../../features/products/presentation/routes.dart';
import '../../features/profiles/presentation/routes.dart';
import '../../features/settings/presentation/routes.dart';
import '../../features/stock/presentation/routes.dart';
import '../platform/impl/dev_routes.dart';
import 'feature_routes_contract.dart';

/// Order matters only within a feature (literal paths before `:param` paths).
List<FeatureRoutes> get allFeatureRoutes => [
      onboardingRoutes,
      profilesRoutes,
      dashboardRoutes,
      productsRoutes,
      categoriesRoutes,
      pricingRoutes,
      stockRoutes,
      alertsRoutes,
      importExportRoutes,
      backupRoutes,
      settingsRoutes,
      devPlatformRoutes,
    ];
