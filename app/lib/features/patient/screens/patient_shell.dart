import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

/// Bottom-navigation frame for the patient's three top-level tabs. Every
/// other patient route (intake, call, checkout...) is pushed full-screen on
/// top, so focused flows don't show the tab bar.
class PatientShell extends StatelessWidget {
  const PatientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.house),
            selectedIcon: Icon(LucideIcons.house, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.stethoscope),
            selectedIcon: Icon(
              LucideIcons.stethoscope,
              color: AppColors.primary,
            ),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.layoutList),
            selectedIcon: Icon(
              LucideIcons.layoutList,
              color: AppColors.primary,
            ),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
