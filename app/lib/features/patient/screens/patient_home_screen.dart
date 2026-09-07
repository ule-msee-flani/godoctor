import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentPatientProfileProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: profile.when(
                    data: (p) => Text(
                      p != null && p.name.isNotEmpty
                          ? 'Hi, ${p.name.split(' ').first}'
                          : 'Welcome',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    loading: () => Text(
                      'Welcome',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    error: (_, _) => Text(
                      'Welcome',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.inkSoft,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  icon: const Icon(LucideIcons.logOut),
                  tooltip: 'Sign out',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'What do you need today?',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            AppImage(
              assetPath: 'assets/images/home_banner.png',
              height: 140,
              borderRadius: 24,
              placeholderIcon: LucideIcons.heartPulse,
              placeholderLabel: 'assets/images/home_banner.png',
              gradient: AppColors.primaryGradient,
            ),
            const SizedBox(height: 20),
            _PrimaryAction(
              icon: LucideIcons.video,
              title: 'See a Doctor',
              subtitle: 'Start a video consultation now',
              color: AppColors.primary,
              onTap: () => context.push('/patient/intake'),
            ),
            const SizedBox(height: 14),
            _PrimaryAction(
              icon: LucideIcons.pill,
              title: 'Order Medicine',
              subtitle: 'Search stock at nearby chemists',
              color: AppColors.accentTeal,
              onTap: () => context.push('/patient/medicine-search'),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _SecondaryAction(
                    icon: LucideIcons.history,
                    label: 'Consultations',
                    onTap: () => context.push('/patient/consultation-history'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryAction(
                    icon: LucideIcons.receipt,
                    label: 'Orders',
                    onTap: () => context.push('/patient/order-history'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SecondaryAction(
              icon: LucideIcons.fileText,
              label: 'My prescriptions',
              onTap: () => context.push('/patient/prescriptions'),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
