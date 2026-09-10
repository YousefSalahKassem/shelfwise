// OWNER: lead. Navigation shell: bottom bar on phones, rail on tablets/desktop.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../core/router/route_paths.dart';
import '../core/theme/spacing.dart';
import '../core/widgets/brand_logo.dart';
import '../features/alerts/public.dart';

class _Destination {
  const _Destination(this.path, this.icon, this.selectedIcon, this.label);
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations) label;
}

final _destinations = <_Destination>[
  _Destination(
    RoutePaths.dashboard,
    Icons.home_outlined,
    Icons.home,
    (l) => l.common_navDashboard,
  ),
  _Destination(
    RoutePaths.products,
    Icons.inventory_2_outlined,
    Icons.inventory_2,
    (l) => l.common_navProducts,
  ),
  _Destination(
    RoutePaths.stock,
    Icons.move_to_inbox_outlined,
    Icons.move_to_inbox,
    (l) => l.common_navStock,
  ),
  _Destination(
    RoutePaths.alerts,
    Icons.notifications_outlined,
    Icons.notifications,
    (l) => l.common_navAlerts,
  ),
  _Destination(
    RoutePaths.settings,
    Icons.settings_outlined,
    Icons.settings,
    (l) => l.common_navSettings,
  ),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _index {
    for (var i = 0; i < _destinations.length; i++) {
      final p = _destinations[i].path;
      if (location == p || location.startsWith('$p/')) return i;
    }
    if (location.startsWith('/categories') || location.startsWith('/prices'))
      return 1;
    return 0;
  }

  Widget _icon(int i, {required bool selected}) {
    final d = _destinations[i];
    final icon = Icon(selected ? d.selectedIcon : d.icon);
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.medium;
    void go(int i) => context.go(_destinations[i].path);

    if (!wide) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: go,
          destinations: [
            for (var i = 0; i < _destinations.length; i++)
              NavigationDestination(
                icon: _icon(i, selected: false),
                selectedIcon: _icon(i, selected: true),
                label: _destinations[i].label(l10n),
              ),
          ],
        ),
      );
    }
    final extended = MediaQuery.sizeOf(context).width >= Breakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            selectedIndex: _index,
            onDestinationSelected: go,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: BrandLogo(size: 40),
            ),
            destinations: [
              for (var i = 0; i < _destinations.length; i++)
                NavigationRailDestination(
                  icon: _icon(i, selected: false),
                  selectedIcon: _icon(i, selected: true),
                  label: Text(_destinations[i].label(l10n)),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
