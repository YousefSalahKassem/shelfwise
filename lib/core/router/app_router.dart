import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shell/app_shell.dart';
import '../brand/brand_providers.dart';
import '../session/session_impl.dart';
import 'feature_routes.dart';
import 'guards.dart';
import 'route_paths.dart';

part 'app_router.g.dart';

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionControllerProvider, (_, _) => refresh.value++);
  ref.listen(featureFlagsProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final routes = allFeatureRoutes;
  final router = GoRouter(
    initialLocation: RoutePaths.initial,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(
      location: state.uri.toString(),
      session: ref.read(sessionControllerProvider),
      flags: ref.read(featureFlagsProvider),
      isDebug: kDebugMode,
    ),
    routes: [
      for (final f in routes) ...f.fullscreen,
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
        routes: [for (final f in routes) ...f.shell],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
