import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_providers.dart';
import '../family/family_providers.dart';
import '../../../core/widgets/motion.dart';

/// Bottom-navigation frame for the patient's top-level tabs. Every other
/// patient route (intake, call, checkout...) is pushed full-screen on top,
/// so focused flows don't show the tab bar.
/// A bottom-bar tab whose icon pops when chosen and, with a [badge],
/// floats gently until it's read.
NavigationDestination _tab(IconData icon, String label, {int badge = 0}) =>
    NavigationDestination(
      icon: Bobbing(
        active: badge > 0,
        child: PopBadge(count: badge, child: Icon(icon)),
      ),
      selectedIcon: TabPop(
        child: PopBadge(count: badge, child: Icon(icon)),
      ),
      label: label,
    );

class PatientShell extends ConsumerWidget {
  const PatientShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep "online" fresh so family can invite me into their consultations.
    ref.watch(presenceHeartbeatProvider);
    final unreadChats = ref.watch(unreadChatsProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          _tab(LucideIcons.house, 'Home'),
          _tab(LucideIcons.stethoscope, 'Doctors'),
          _tab(LucideIcons.messagesSquare, 'Chats', badge: unreadChats),
          _tab(LucideIcons.heartPulse, 'Health'),
          _tab(LucideIcons.user, 'Profile'),
        ],
      ),
    );
  }
}
