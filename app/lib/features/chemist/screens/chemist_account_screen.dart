import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/settings_section.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/geocoding.dart';
import '../../patient/profile/account_screen.dart'
    show showChangePasswordDialog;
import '../../support/rate_app_sheet.dart';

/// Chemist "Account" tab: photo, pharmacy location (used to rank chemists
/// by distance for patients), support and account settings.
class ChemistAccountScreen extends ConsumerWidget {
  const ChemistAccountScreen({super.key});

  Future<void> _setLocation(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentChemistProfileProvider).valueOrNull;
    if (profile == null) return;
    final initial = profile.locationLat != null && profile.locationLng != null
        ? Place(
            name: profile.locationName ?? 'Pharmacy location',
            lat: profile.locationLat!,
            lng: profile.locationLng!,
          )
        : null;
    final picked = await context.push<Place>(
      '/account/location',
      extra: initial,
    );
    if (picked == null) return;
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateChemistLocation(
            userId: profile.userId,
            name: picked.name,
            lat: picked.lat,
            lng: picked.lng,
          );
      ref.invalidate(currentChemistProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pharmacy location saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final profile = ref.watch(currentChemistProfileProvider).valueOrNull;
    final email =
        ref.watch(authRepositoryProvider).currentAuthUser?.email ?? '';
    final name = (profile?.businessName.isNotEmpty ?? false)
        ? profile!.businessName
        : 'Your pharmacy';

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  EditableAvatar(name: name, radius: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.titleLarge),
                        if (email.isNotEmpty)
                          Text(email, style: theme.bodyMedium),
                        if (profile?.verified ?? false)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  LucideIcons.badgeCheck,
                                  size: 14,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Verified pharmacy',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Pharmacy',
                children: [
                  SettingsTile(
                    icon: LucideIcons.mapPin,
                    title: 'Location',
                    subtitle:
                        profile?.locationName ??
                        (profile?.locationLat != null
                            ? 'Set, but without a place name. Tap to update.'
                            : 'Not set: patients cannot see how near you are'),
                    onTap: () => _setLocation(context, ref),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Support & feedback',
                children: [
                  SettingsTile(
                    icon: LucideIcons.headset,
                    title: 'Contact support',
                    onTap: () => context.push('/account/support'),
                  ),
                  SettingsTile(
                    icon: LucideIcons.flag,
                    title: 'Report a complaint',
                    onTap: () =>
                        context.push('/account/support/new?kind=complaint'),
                  ),
                  SettingsTile(
                    icon: LucideIcons.bellRing,
                    title: 'Notifications',
                    subtitle: 'What GoDoctor alerts you about',
                    onTap: () => context.push('/account/notifications'),
                  ),
                  SettingsTile(
                    icon: LucideIcons.star,
                    title: 'Rate GoDoctor',
                    onTap: () => showRateAppSheet(context),
                  ),
                ],
              ),
              SettingsSection(
                title: 'Account settings',
                children: [
                  if (email.isNotEmpty)
                    SettingsTile(
                      icon: LucideIcons.keyRound,
                      title: 'Change password',
                      onTap: () => showChangePasswordDialog(context, ref),
                    ),
                  SettingsTile(
                    icon: LucideIcons.logOut,
                    title: 'Sign out',
                    onTap: () => ref.read(authRepositoryProvider).signOut(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
