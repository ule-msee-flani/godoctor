import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

/// Hard stop shown when the emergency keyword check trips. Always gives a
/// path to reach a human -- never a dead end (per spec). Shared by the
/// on-demand intake form and scheduled-appointment booking.
class EmergencyStopView extends StatelessWidget {
  const EmergencyStopView({super.key, this.matchedKeyword});

  final String? matchedKeyword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dangerSoft,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Center(
                  child: Icon(
                    LucideIcons.briefcaseMedical,
                    color: AppColors.ink,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'This sounds like a medical emergency',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: 12),
              Text(
                'GoDoctor cannot safely handle this over a delayed video consultation. '
                'Please contact emergency services or go to the nearest hospital right away.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => launchDialer('999'),
                icon: const Icon(LucideIcons.phoneCall, size: 18),
                label: const Text('Call 999 (Emergency Services)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the device dialer via a `tel:` link. On desktop web where no
/// dialer app is registered this silently no-ops (browser handles it), but
/// the number is also shown on-screen so it's never a dead end.
Future<void> launchDialer(String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  try {
    await launchUrl(uri);
  } catch (_) {
    // No dialer available (e.g. plain desktop browser) -- the number is
    // already visible in the button label for the user to dial manually.
  }
}
