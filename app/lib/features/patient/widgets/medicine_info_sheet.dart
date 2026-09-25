import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/drug_info.dart';
import '../../../data/models/medicine_category.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import 'medicine_image.dart';

final drugInfoProvider = FutureProvider.autoDispose.family<DrugInfo?, String>(
  (ref, drugId) => ref.watch(drugRepositoryProvider).fetchInfo(drugId),
);

/// "About this medicine": what it's for, warnings, side effects and
/// interactions, from the public drug label imported into `drug_info`.
Future<void> showMedicineInfoSheet(BuildContext context, Drug drug) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) =>
          _MedicineInfo(drug: drug, controller: controller),
    ),
  );
}

class _MedicineInfo extends ConsumerWidget {
  const _MedicineInfo({required this.drug, required this.controller});

  final Drug drug;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final info = ref.watch(drugInfoProvider(drug.id));
    final category = MedicineCategory.fromForm(drug.form);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Row(
          children: [
            MedicineImage(drug: drug, size: 64, radius: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(drug.genericName, style: theme.titleLarge),
                  Text(
                    [
                      if (drug.form != null) drug.form!,
                      category.label,
                    ].join('  ·  '),
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (drug.requiresPrescription) ...[
          const SizedBox(height: 14),
          _Notice(
            icon: LucideIcons.fileText,
            color: AppColors.warning,
            text:
                'This medicine needs a valid prescription. A doctor on GoDoctor can prescribe it if it is right for you.',
          ),
        ],
        const SizedBox(height: 18),
        info.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: LoadingView(),
          ),
          error: (e, _) => Text(friendlyError(e)),
          data: (i) {
            if (i == null || i.isEmpty) {
              return _Notice(
                icon: LucideIcons.info,
                color: AppColors.primary,
                text:
                    'Detailed information for this medicine is not available yet. '
                    'Ask the pharmacist or a doctor for advice on using it.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i.uses != null)
                  _Section(
                    icon: LucideIcons.target,
                    title: 'What it is used for',
                    text: i.uses!,
                    color: AppColors.primary,
                  ),
                if (i.warnings != null)
                  _Section(
                    icon: LucideIcons.triangleAlert,
                    title: 'Important warnings',
                    text: i.warnings!,
                    color: AppColors.danger,
                  ),
                if (i.sideEffects != null)
                  _Section(
                    icon: LucideIcons.activity,
                    title: 'Possible side effects',
                    text: i.sideEffects!,
                    color: AppColors.warning,
                  ),
                if (i.interactions != null)
                  _Section(
                    icon: LucideIcons.pillBottle,
                    title: 'Other medicines to be careful with',
                    text: i.interactions!,
                    color: AppColors.accentTeal,
                  ),
                const SizedBox(height: 4),
                _Notice(
                  icon: LucideIcons.stethoscope,
                  color: AppColors.inkSoft,
                  text:
                      'Always take medicines exactly as your doctor or pharmacist tells you. '
                      'This summary is general information, not medical advice.',
                ),
                const SizedBox(height: 14),
                Text(
                  'Source: US drug label via ${i.source}'
                  '${i.matchedName != null && i.matchedName!.toLowerCase() != drug.genericName.toLowerCase() ? ' (listed there as ${i.matchedName})' : ''}. '
                  'Brands and strengths sold in Kenya may differ.',
                  style: theme.bodySmall,
                ),
                if (i.sourceUrl != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => launchUrl(
                        Uri.parse(i.sourceUrl!),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(LucideIcons.externalLink, size: 16),
                      label: const Text('Read the full label'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(title, style: theme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: theme.bodyMedium?.copyWith(
              color: AppColors.ink,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
