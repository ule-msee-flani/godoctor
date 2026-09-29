import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_providers.dart';
import '../family/family_providers.dart';
import '../../../core/widgets/exit_guard.dart';
import '../../../core/widgets/floating_nav_bar.dart';

/// Bottom-navigation frame for the patient's top-level tabs. Every other
/// patient route (intake, call, checkout...) is pushed full-screen on top,
/// so focused flows don't show the tab bar.
class PatientShell extends ConsumerWidget {
  const PatientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep "online" fresh so family can invite me into their consultations.
    ref.watch(presenceHeartbeatProvider);
    final unreadChats = ref.watch(unreadChatsProvider);

    return ExitGuard(
      onBack: () {
        if (navigationShell.currentIndex == 0) return false;
        navigationShell.goBranch(0);
        return true;
      },
      child: Scaffold(
        body: navigationShell,
        // A floating pill: the chosen tab grows into a capsule with its name.
        bottomNavigationBar: FloatingNavBar(
          currentIndex: navigationShell.currentIndex,
          onTap: (i) => navigationShell.goBranch(
            i,
            initialLocation: i == navigationShell.currentIndex,
          ),
          items: [
            const FloatingNavItem(LucideIcons.house, 'Home'),
            const FloatingNavItem(LucideIcons.stethoscope, 'Doctors'),
            FloatingNavItem(
              LucideIcons.messagesSquare,
              'Chats',
              badge: unreadChats,
            ),
            const FloatingNavItem(LucideIcons.heartPulse, 'Health'),
            const FloatingNavItem(LucideIcons.user, 'Profile'),
          ],
        ),
      ),
    );
  }
}
