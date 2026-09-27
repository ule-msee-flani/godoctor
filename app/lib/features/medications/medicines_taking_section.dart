import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/medication.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'medication_providers.dart';

/// "Medicines you're taking": each course with reminders on, as a ring
/// (day X of Y), the next dose time and a Taken button. Hidden when there
/// are none.
class MedicinesTakingSection extends ConsumerWidget {
  const MedicinesTakingSection({super.key, this.title = true});

  final bool title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(activeSchedulesProvider).valueOrNull ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title) ...[
          Text(
            'Medicines you\'re taking',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
        ],
        for (final s in list) ...[
          MedicineCourseCard(schedule: s),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class MedicineCourseCard extends ConsumerStatefulWidget {
  const MedicineCourseCard({super.key, required this.schedule});

  final MedicationSchedule schedule;

  @override
  ConsumerState<MedicineCourseCard> createState() => _MedicineCourseCardState();
}

class _MedicineCourseCardState extends ConsumerState<MedicineCourseCard> {
  bool _busy = false;

  Future<void> _taken() async {
    setState(() => _busy = true);
    final repo = ref.read(medicationRepositoryProvider);
    final pending = widget.schedule.pendingDose;
    try {
      if (pending != null) {
        await repo.markDose(pending.id, taken: true);
      } else {
        await repo.logTakenNow(widget.schedule.id);
      }
      HapticFeedback.lightImpact();
      ref.invalidate(activeSchedulesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop these reminders?'),
        content: Text(
          'You won\'t get reminders for ${widget.schedule.drugName} any more.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(medicationRepositoryProvider).stop(widget.schedule.id);
    ref.invalidate(activeSchedulesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final s = widget.schedule;
    final now = DateTime.now();
    final day = s.dayOfCourse(now);
    final next = s.nextDose(now);
    final pending = s.pendingDose;
    final takenToday = s.logs.any(
      (l) => l.status == 'taken' && isSameDay(l.takenAt ?? l.dueAt, now),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pending != null ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: day / s.totalDays,
                    strokeWidth: 4,
                    backgroundColor: AppColors.primarySoft,
                    color: AppColors.primary,
                  ),
                ),
                Text('$day', style: theme.titleSmall),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.drugName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
                Text(
                  [
                    'Day $day of ${s.totalDays}',
                    if (pending != null)
                      'Due now'
                    else if (next != null)
                      'Next ${isSameDay(next, now) ? formatTime(next) : formatRelativeSlot(next)}',
                  ].join(' · '),
                  style: theme.bodySmall,
                ),
                if (s.takenCount > 0)
                  Text(
                    '${s.takenCount} ${s.takenCount == 1 ? 'dose' : 'doses'} taken. Keep going.',
                    style: theme.bodySmall?.copyWith(color: AppColors.success),
                  ),
              ],
            ),
          ),
          if (pending != null || !takenToday)
            TextButton(
              onPressed: _busy ? null : _taken,
              child: const Text('Taken'),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedCheck(size: 30),
            ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
            onSelected: (_) => _stop(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'stop', child: Text('Stop reminders')),
            ],
          ),
        ],
      ),
    );
  }
}
