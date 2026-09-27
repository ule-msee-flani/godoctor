import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/local_touch.dart';
import '../../../data/models/enums.dart';
import '../widgets/auth_hero.dart';
import '../widgets/role_icons.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/exit_guard.dart';

/// First screen: the hero photo, the app icon, and "who are you?".
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ExitGuard(
      child: AuthHeroScaffold(
        image: 'assets/images/auth/auth_hero',
        alignment: const Alignment(-0.35, 0),
        heightFactor: 0.42,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppIconMark(size: 64)),
              const SizedBox(height: 16),
              Text(
                '${LocalTouch.welcome} to GoDoctor',
                textAlign: TextAlign.center,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Consult a doctor or order medicine, wherever you are.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 24),
              for (final r in _roles) ...[
                FadeSlideIn(
                  index: _roles.indexOf(r),
                  child: Pressable(
                    child: _RoleCard(
                      role: r.role,
                      title: r.title,
                      subtitle: r.subtitle,
                      onTap: () => context.go(
                        '/auth/login/${EnumDbCoding.toDb(r.role)}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const _roles = [
    (
      role: UserRole.patient,
      title: 'I am a patient',
      subtitle: 'See a doctor or order medicine',
    ),
    (
      role: UserRole.doctor,
      title: 'I am a doctor',
      subtitle: 'Consult patients and prescribe',
    ),
    (
      role: UserRole.chemist,
      title: 'I am a chemist',
      subtitle: 'Manage stock and fill orders',
    ),
  ];
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              RoleIcon(role: role, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: AppColors.ink,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
