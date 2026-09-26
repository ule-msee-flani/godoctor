import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_providers.dart';
import '../widgets/emergency_stop_view.dart' show launchDialer;

/// A quiet, always-there way out: "Emergency? 999 · 1199", tap to call, and
/// share my saved location with someone. Deliberately calm (no red) so it
/// doesn't alarm anyone who doesn't need it.
class EmergencyStrip extends ConsumerWidget {
  const EmergencyStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final profile = ref.watch(currentPatientProfileProvider).valueOrNull;
    final lat = profile?.locationLat, lng = profile?.locationLng;

    Widget number(String n) => InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => launchDialer(n),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Text(
          n,
          style: theme.titleSmall?.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.inkFaint,
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.phone, size: 16, color: AppColors.inkSoft),
          const SizedBox(width: 8),
          Text('Emergency?', style: theme.bodyMedium),
          const SizedBox(width: 4),
          number('999'),
          Text('·', style: theme.bodyMedium),
          number('1199'),
          const Spacer(),
          if (lat != null && lng != null)
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.ink,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'I need help. My location: '
                      'https://maps.google.com/?q=$lat,$lng'
                      '${profile?.locationName == null ? '' : ' (${profile!.locationName})'}',
                ),
              ),
              icon: const Icon(LucideIcons.mapPin, size: 16),
              label: const Text('Share location'),
            ),
        ],
      ),
    );
  }
}
