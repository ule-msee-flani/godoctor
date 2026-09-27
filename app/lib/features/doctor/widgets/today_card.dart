import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../core/widgets/motion.dart';

final doctorTodayProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(consultationRepositoryProvider).doctorTodayStats(),
);

/// Today at a glance: patients seen, earnings, rating, open chats.
class DoctorTodayCard extends ConsumerWidget {
  const DoctorTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(doctorTodayProvider).valueOrNull;
    final theme = Theme.of(context).textTheme;
    num n(String k) => (stats?[k] as num?) ?? 0;
    final rating = stats?['rating'] as num?;
    final openChats = n('open_chats').toInt();

    Widget stat(
      String value,
      String label, {
      VoidCallback? onTap,
      num? countTo,
      String Function(num v)? format,
    }) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              if (stats != null && countTo != null)
                CountUp(
                  value: countTo,
                  format: format ?? (v) => '$v',
                  style: theme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                )
              else
                Text(
                  stats == null ? '–' : value,
                  maxLines: 1,
                  style: theme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              const SizedBox(height: 2),
              Text(label, style: theme.bodySmall),
            ],
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text('Today', style: theme.titleMedium),
          ),
          Row(
            children: [
              stat(
                '${n('patients')}',
                'Patients',
                countTo: n('patients').toInt(),
              ),
              stat(
                formatKes(
                  n('earnings').toDouble(),
                ).replaceFirst('Free', 'KES 0'),
                'Earned',
                countTo: n('earnings').toInt(),
                format: (v) =>
                    formatKes(v.toDouble()).replaceFirst('Free', 'KES 0'),
              ),
              stat(
                rating == null || n('ratings') == 0
                    ? 'New'
                    : rating.toStringAsFixed(1),
                'Rating',
              ),
              stat(
                '$openChats',
                'Open chats',
                countTo: openChats,
                onTap: () => context.go('/doctor/chats'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
