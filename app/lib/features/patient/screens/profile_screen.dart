import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/settings_section.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../support/rate_app_sheet.dart';
import '../family/family_providers.dart';

/// The patient's Profile tab: photo, name and email on top, then
/// Profile · Family · Billing information · Support & feedback.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final profile = ref.watch(currentPatientProfileProvider).valueOrNull;
    final authUser = ref.watch(authRepositoryProvider).currentAuthUser;
    final email = (authUser?.email?.isNotEmpty ?? false)
        ? authUser!.email!
        : (authUser?.phone ?? '');
    final name = (profile?.name.isNotEmpty ?? false)
        ? profile!.name
        : 'Add your name';
    final pendingFamily = ref.watch(pendingFamilyInvitesProvider);

    String? summary(List<String?> parts) {
      final s = parts.whereType<String>().where((p) => p.isNotEmpty).join(', ');
      return s.isEmpty ? null : s;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          // --- Header ---
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: EditableAvatar(name: name, radius: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: theme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      if (profile?.locationName != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.mapPin,
                              size: 13,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                profile!.locationName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SettingsSection(
            title: 'Profile',
            children: [
              SettingsTile(
                icon: LucideIcons.userRound,
                title: 'User profile',
                subtitle: 'Personal details, contact info, account settings',
                onTap: () => context.push('/patient/profile/account'),
              ),
              SettingsTile(
                icon: LucideIcons.heartPulse,
                title: 'Health details',
                subtitle:
                    summary([
                      profile?.bloodGroup,
                      if ((profile?.allergies ?? '').isNotEmpty)
                        'allergies noted',
                      if ((profile?.chronicConditions ?? '').isNotEmpty)
                        'conditions noted',
                    ]) ??
                    'Allergies, medications, conditions',
                onTap: () => context.push('/patient/profile/health'),
              ),
              SettingsTile(
                icon: LucideIcons.mapPin,
                title: 'Location',
                subtitle: profile?.locationName ?? 'Not set yet',
                onTap: () => context.push('/patient/profile/location'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Family',
            children: [
              SettingsTile(
                icon: LucideIcons.users,
                title: 'Family members',
                subtitle: pendingFamily > 0
                    ? '$pendingFamily invitation${pendingFamily == 1 ? '' : 's'} waiting for you'
                    : 'Invite family to listen in on your consultations',
                badge: pendingFamily,
                onTap: () => context.push('/patient/profile/family'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Billing information',
            children: [
              SettingsTile(
                icon: LucideIcons.wallet,
                title: 'Payment methods',
                subtitle: 'M-Pesa numbers, cards, preferences and history',
                onTap: () => context.push('/patient/profile/billing'),
              ),
            ],
          ),
          SettingsSection(
            title: 'Support & feedback',
            children: [
              SettingsTile(
                icon: LucideIcons.headset,
                title: 'Contact support',
                subtitle: 'Chat with the GoDoctor support team',
                onTap: () => context.push('/account/support'),
              ),
              SettingsTile(
                icon: LucideIcons.messageSquareHeart,
                title: 'Give feedback',
                subtitle: 'Ideas to make GoDoctor better',
                onTap: () => context.push('/account/support/new?kind=feedback'),
              ),
              SettingsTile(
                icon: LucideIcons.star,
                title: 'Rate GoDoctor',
                onTap: () => showRateAppSheet(context),
              ),
              SettingsTile(
                icon: LucideIcons.flag,
                title: 'Report a complaint',
                subtitle: 'About a consultation, order or anything else',
                onTap: () =>
                    context.push('/account/support/new?kind=complaint'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const InstallPromptBanner(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
