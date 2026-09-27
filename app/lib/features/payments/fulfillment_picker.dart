import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/auth_providers.dart';

/// "How do you want it?": collect from the chemist, or delivered to the
/// patient's saved location.
class FulfillmentPicker extends ConsumerWidget {
  const FulfillmentPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.chemistName,
  });

  /// 'pickup' or 'delivery'.
  final String value;
  final ValueChanged<String> onChanged;
  final String? chemistName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final place = ref.watch(currentPatientProfileProvider).valueOrNull;
    final address = place?.locationName;

    Widget option(String v, IconData icon, String title, String subtitle) {
      final on = value == v;
      return Expanded(
        child: Material(
          color: on ? AppColors.primarySofter : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: on ? AppColors.primary : AppColors.border,
              width: on ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onChanged(v),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 20, color: AppColors.ink),
                      const Spacer(),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          on ? LucideIcons.circleCheck : LucideIcons.circle,
                          key: ValueKey(on),
                          size: 18,
                          color: on ? AppColors.primary : AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title, style: theme.titleSmall),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How do you want it?', style: theme.titleMedium),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              option(
                'pickup',
                LucideIcons.store,
                'Pick up',
                chemistName == null
                    ? 'Collect from the chemist'
                    : 'Collect from $chemistName',
              ),
              const SizedBox(width: 10),
              option(
                'delivery',
                LucideIcons.bike,
                'Delivery',
                address == null ? 'To your saved location' : 'To $address',
              ),
            ],
          ),
        ),
        if (value == 'delivery')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address == null
                        ? 'Add your location so the chemist knows where to deliver.'
                        : 'The chemist will call you to arrange delivery.',
                    style: theme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/patient/profile/location'),
                  child: Text(address == null ? 'Add location' : 'Change'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// "Your money is held safely until you confirm you received it."
class EscrowNote extends StatelessWidget {
  const EscrowNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            LucideIcons.shieldCheck,
            size: 16,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your money is held safely and only paid to the chemist once you '
            'confirm you received your medicine.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
