import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_providers.dart';
import '../family/family_providers.dart';

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

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        destinations: [
          const NavigationDestination(
            icon: Icon(LucideIcons.house),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.stethoscope),
            label: 'Doctors',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadChats > 0,
              label: Text('$unreadChats'),
              child: const Icon(LucideIcons.messagesSquare),
            ),
            label: 'Chats',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.heartPulse),
            label: 'Health',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.user),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
