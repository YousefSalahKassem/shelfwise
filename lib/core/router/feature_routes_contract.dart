import 'package:go_router/go_router.dart';

/// What each feature's `presentation/routes.dart` exposes.
/// `shell` routes render inside the navigation shell; `fullscreen` ones don't.
/// Paths must be absolute and come from [RoutePaths].
class FeatureRoutes {
  const FeatureRoutes({this.shell = const [], this.fullscreen = const []});
  final List<RouteBase> shell;
  final List<RouteBase> fullscreen;
}
