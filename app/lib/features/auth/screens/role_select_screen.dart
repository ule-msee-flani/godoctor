import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../data/models/enums.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primarySofter,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: AppImage(
                  assetPath: 'assets/images/auth_hero.png',
                  height: 220,
                  borderRadius: 28,
                  placeholderIcon: LucideIcons.video,
                  placeholderLabel: 'assets/images/auth_hero.png',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(
                              LucideIcons.heartPulse,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'GoDoctor',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Consult a doctor or order medicine,\nwherever you are.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 28),
                    _RoleCard(
                      icon: LucideIcons.user,
                      title: 'I am a patient',
                      subtitle: 'See a doctor or order medicine',
                      color: AppColors.primary,
                      onTap: () =>
                          context.go('/auth/login/${_role(UserRole.patient)}'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: LucideIcons.stethoscope,
                      title: 'I am a doctor',
                      subtitle: 'Accept consultations, issue prescriptions',
                      color: AppColors.accentTeal,
                      onTap: () =>
                          context.go('/auth/login/${_role(UserRole.doctor)}'),
                    ),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: LucideIcons.pill,
                      title: 'I am a chemist',
                      subtitle: 'Manage inventory, fulfill orders',
                      color: AppColors.primaryDark,
                      onTap: () =>
                          context.go('/auth/login/${_role(UserRole.chemist)}'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _role(UserRole role) => EnumDbCoding.toDb(role);
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Icon(icon, color: color, size: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.inkFaint,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
