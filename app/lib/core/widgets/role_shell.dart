import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'motion.dart';
import 'exit_guard.dart';
import 'floating_nav_bar.dart';

/// One tab in a [RoleShell].
class ShellTab {
  const ShellTab(this.icon, this.label, {this.badge = 0});

  final IconData icon;
  final String label;

  /// Count shown on the tab (0 hides it).
  final int badge;
}

/// Bottom navigation for the doctor and chemist apps (a side rail on wide
/// desktop screens). Focused screens such as the consultation call are
/// pushed on top, so they show no tab bar.
class RoleShell extends StatelessWidget {
  const RoleShell({
    super.key,
    required this.navigationShell,
    required this.tabs,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellTab> tabs;

  void _go(int i) => navigationShell.goBranch(
    i,
    initialLocation: i == navigationShell.currentIndex,
  );

  Widget _icon(ShellTab t, {bool selected = false}) {
    final icon = PopBadge(
      count: t.badge,
      child: Icon(t.icon, color: selected ? AppColors.ink : null),
    );
    return selected
        ? TabPop(child: icon)
        : Bobbing(active: t.badge > 0, child: icon);
  }

  Widget get _body => navigationShell;

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      onBack: () {
        if (navigationShell.currentIndex == 0) return false;
        _go(0);
        return true;
      },
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final t in tabs)
                  NavigationRailDestination(
                    icon: _icon(t),
                    selectedIcon: _icon(t, selected: true),
                    label: Text(t.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _body),
          ],
        ),
      );
    }
    return Scaffold(
      body: _body,
      bottomNavigationBar: FloatingNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _go,
        items: [
          for (final t in tabs)
            FloatingNavItem(t.icon, t.label, badge: t.badge),
        ],
      ),
    );
  }
}
