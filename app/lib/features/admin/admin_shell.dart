import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/repository_providers.dart';
import 'widgets/admin_ui.dart';
import '../../core/widgets/exit_guard.dart';

class _NavItem {
  const _NavItem(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;
}

const _groups = <(String, List<_NavItem>)>[
  (
    'Monitor',
    [
      _NavItem('/admin', 'Overview', LucideIcons.layoutDashboard),
      _NavItem('/admin/activity', 'Live traffic', LucideIcons.activity),
      _NavItem('/admin/database', 'Database', LucideIcons.database),
      _NavItem('/admin/notifications', 'Notifications', LucideIcons.bell),
    ],
  ),
  (
    'Manage',
    [
      _NavItem('/admin/users', 'Users', LucideIcons.users),
      _NavItem('/admin/verification', 'Verification', LucideIcons.shieldCheck),
      _NavItem(
        '/admin/consultations',
        'Consultations',
        LucideIcons.stethoscope,
      ),
      _NavItem('/admin/orders', 'Orders', LucideIcons.shoppingBag),
      _NavItem('/admin/payments', 'Payments', LucideIcons.wallet),
    ],
  ),
  (
    'Engage',
    [
      _NavItem('/admin/support', 'Support', LucideIcons.headset),
      _NavItem('/admin/broadcast', 'Announcements', LucideIcons.megaphone),
    ],
  ),
];

/// The super-admin console frame: a dark sidebar on wide screens (a drawer
/// on phones) and the selected page beside it.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  bool _selected(String path) => path == '/admin'
      ? location == '/admin'
      : location == path || location.startsWith('$path/');

  String get _title {
    for (final (_, items) in _groups) {
      for (final i in items) {
        if (_selected(i.path)) return i.label;
      }
    }
    return 'Admin';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExitGuard(
      onBack: () {
        if (location == '/admin') return false;
        context.go('/admin');
        return true;
      },
      child: _build(context, ref),
    );
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width >= 1000;
    final sidebar = _Sidebar(
      selected: _selected,
      onSignOut: () => ref.read(authRepositoryProvider).signOut(),
      onNavigate: (path) {
        if (!wide) Navigator.of(context).pop();
        context.go(path);
      },
    );

    if (wide) {
      return Scaffold(
        backgroundColor: AdminColors.page,
        body: Row(
          children: [
            SizedBox(width: 248, child: sidebar),
            Expanded(child: child),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AdminColors.page,
      appBar: AppBar(title: Text(_title)),
      drawer: Drawer(width: 264, child: sidebar),
      body: child,
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.onNavigate,
    required this.onSignOut,
  });

  final bool Function(String path) selected;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: AdminColors.sidebar,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/logo/app_icon.png',
                      width: 32,
                      height: 32,
                      errorBuilder: (_, _, _) => const SizedBox(width: 32),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GoDoctor',
                          style: theme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Super admin',
                          style: theme.bodySmall?.copyWith(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final (group, items) in _groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
                      child: Text(
                        group.toUpperCase(),
                        style: theme.labelSmall?.copyWith(
                          color: Colors.white38,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final item in items)
                      _NavTile(
                        item: item,
                        selected: selected(item.path),
                        onTap: () => onNavigate(item.path),
                      ),
                  ],
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            ListTile(
              leading: const Icon(LucideIcons.logOut, color: Colors.white70),
              title: Text(
                'Sign out',
                style: theme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? AdminColors.sidebarActive : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.white60,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (selected) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
