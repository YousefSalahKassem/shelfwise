import '../auth/permission.dart';
import '../brand/feature_flag.dart';
import '../brand/feature_flags.dart';
import '../session/session_reader.dart';
import 'route_paths.dart';

/// Route → permission needed. Frozen contract (TECHNICAL_STRUCTURE §10).
const Map<String, Permission> routePermissions = {
  RoutePaths.productNew: Permission.editCatalogue,
  RoutePaths.productEdit: Permission.editCatalogue,
  RoutePaths.stockAdjust: Permission.adjustStock,
  RoutePaths.stockReceive: Permission.recordStock,
  RoutePaths.pricesBulk: Permission.editPrices,
  RoutePaths.priceEdit: Permission.editPrices,
  RoutePaths.settingsProfiles: Permission.manageProfiles,
  RoutePaths.settingsBackup: Permission.backupRestore,
  RoutePaths.settingsImport: Permission.importExport,
};

/// Route → feature flag needed (tier gating).
const Map<String, FeatureFlag> routeFlags = {
  RoutePaths.stockCount: FeatureFlag.stockCount,
};

/// Pure redirect logic so it can be unit-tested without a router.
/// Returns the path to redirect to, or null to allow [location].
String? redirectFor({
  required String location,
  required SessionReader session,
  required FeatureFlags flags,
  bool isDebug = false,
}) {
  final path = Uri.parse(location).path;

  if (!session.hasStore) {
    return path == RoutePaths.onboarding ? null : RoutePaths.onboarding;
  }
  if (path == RoutePaths.onboarding) {
    return session.isUnlocked ? RoutePaths.initial : RoutePaths.lock;
  }
  if (!session.isUnlocked) {
    return path == RoutePaths.lock ? null : RoutePaths.lock;
  }
  if (path == RoutePaths.lock) return RoutePaths.initial;
  if (path == '/' || path.isEmpty) return RoutePaths.initial;
  if (path == RoutePaths.devPlatform && !isDebug) return RoutePaths.initial;

  final pattern = matchRoutePattern(path);
  if (pattern != null) {
    final permission = routePermissions[pattern];
    if (permission != null && !session.can(permission)) return RoutePaths.initial;
    final flag = routeFlags[pattern];
    if (flag != null && !flags.isEnabled(flag)) return RoutePaths.initial;
  }
  return null;
}

final List<String> _patterns = [...routePermissions.keys, ...routeFlags.keys];

/// Returns the [RoutePaths] pattern (e.g. `/products/:id/edit`) matching
/// [path], if it is one of the guarded patterns.
String? matchRoutePattern(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();
  // Prefer literal matches (e.g. /products/new) over parameter matches.
  String? paramMatch;
  for (final pattern in _patterns) {
    final p = pattern.split('/').where((s) => s.isNotEmpty).toList();
    if (p.length != segments.length) continue;
    var literal = true;
    var matches = true;
    for (var i = 0; i < p.length; i++) {
      if (p[i].startsWith(':')) {
        literal = false;
      } else if (p[i] != segments[i]) {
        matches = false;
        break;
      }
    }
    if (!matches) continue;
    if (literal) return pattern;
    paramMatch ??= pattern;
  }
  // '/products/new' must not be treated as a product id.
  if (paramMatch == RoutePaths.productDetail && segments.length == 2 && segments[1] == 'new') {
    return RoutePaths.productNew;
  }
  if (paramMatch == RoutePaths.priceEdit && segments.length == 2 && segments[1] == 'bulk') {
    return RoutePaths.pricesBulk;
  }
  return paramMatch;
}
