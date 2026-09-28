import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/visit.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';

/// Every visit of the signed-in patient, newest first. Live.
final patientVisitsProvider = FutureProvider.autoDispose<List<Visit>>((ref) {
  ref.watch(liveTick(LiveTable.consultations));
  ref.watch(liveTick(LiveTable.prescriptions));
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(consultationRepositoryProvider).myVisits();
});

/// Splits a newest-first list into month sections ("This month",
/// "August", "December 2025"), keeping the order. Pure, for tests.
List<(String, List<T>)> groupByMonth<T>(
  List<T> items,
  DateTime Function(T) dateOf, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final out = <(String, List<T>)>[];
  String label(DateTime d) {
    if (d.year == today.year && d.month == today.month) return 'This month';
    final last = DateTime(today.year, today.month - 1);
    if (d.year == last.year && d.month == last.month) return 'Last month';
    return d.year == today.year
        ? DateFormat('MMMM').format(d)
        : DateFormat('MMMM yyyy').format(d);
  }

  for (final item in items) {
    final l = label(dateOf(item));
    if (out.isNotEmpty && out.last.$1 == l) {
      out.last.$2.add(item);
    } else {
      out.add((l, [item]));
    }
  }
  return out;
}

/// "Today", "Yesterday", "3 days ago", "12 Aug".
String visitWhen(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = DateTime(
    n.year,
    n.month,
    n.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days < 0) return DateFormat('EEE d MMM, HH:mm').format(at);
  if (days == 0) return 'Today, ${DateFormat('HH:mm').format(at)}';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  return at.year == n.year
      ? DateFormat('d MMM').format(at)
      : DateFormat('d MMM yyyy').format(at);
}

/// A month heading in a grouped list.
class MonthHeader extends StatelessWidget {
  const MonthHeader(this.label, {super.key, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.inkSoft,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppColors.inkFaint),
            ),
          ],
          const SizedBox(width: 10),
          const Expanded(child: Divider(height: 1)),
        ],
      ),
    );
  }
}

/// A visit in the Visits list: the doctor, when, why, and what came of it.
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = visit;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(v.route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      name: v.doctorName ?? v.specialty,
                      path: v.doctorAvatar,
                      radius: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.doctorLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${v.specialty} · '
                            '${v.mode == ConsultationMode.scheduled ? 'Appointment' : 'Video visit'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      visitWhen(v.at, now: now),
                      style: text.labelSmall?.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                if (v.symptoms.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    v.symptoms.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: AppColors.ink),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (v.isUpcoming)
                      const _Badge(
                        icon: LucideIcons.calendarClock,
                        label: 'Upcoming',
                        color: AppColors.primary,
                      )
                    else if (v.isOngoing)
                      const _Badge(
                        icon: LucideIcons.activity,
                        label: 'In progress',
                        color: AppColors.accentTeal,
                      ),
                    if (v.prescriptions > 0)
                      _Badge(
                        icon: LucideIcons.fileText,
                        label: v.prescriptions == 1
                            ? '1 prescription'
                            : '${v.prescriptions} prescriptions',
                      ),
                    if (v.hasSummary)
                      const _Badge(
                        icon: LucideIcons.notebookPen,
                        label: 'Doctor\'s notes',
                      ),
                    if (v.chatOpen(now))
                      const _Badge(
                        icon: LucideIcons.messageCircle,
                        label: 'Chat open',
                        color: AppColors.success,
                      ),
                    if (v.isCompleted && v.myRating == null)
                      const _Badge(
                        icon: LucideIcons.star,
                        label: 'Rate this visit',
                        color: AppColors.warning,
                      )
                    else if (v.myRating != null)
                      _Badge(
                        icon: LucideIcons.star,
                        label: 'You rated ${v.myRating}/5',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    this.color = AppColors.inkSoft,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Home: "Your visits" — the latest few, one swipe away, with a way into the
/// full history. Hidden until the patient has a visit.
class RecentVisitsSection extends ConsumerWidget {
  const RecentVisitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visits = ref.watch(patientVisitsProvider).valueOrNull ?? const [];
    final shown = [
      for (final v in visits)
        if (v.isCompleted || v.isOngoing) v,
    ].take(6).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(
            children: [
              Expanded(child: Text('Your visits', style: text.titleMedium)),
              TextButton(
                onPressed: () => context.go('/patient/health?tab=visits'),
                child: const Text('See all'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: shown.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _MiniVisit(visit: shown[i]),
          ),
        ),
      ],
    );
  }
}

class _MiniVisit extends StatelessWidget {
  const _MiniVisit({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = visit;
    final now = DateTime.now();
    final note = v.isOngoing
        ? ('In progress — tap to return', AppColors.accentTeal)
        : v.hasSummary
        ? ('Read the doctor\'s notes', AppColors.primary)
        : v.prescriptions > 0
        ? (
            '${v.prescriptions} ${v.prescriptions == 1 ? 'prescription' : 'prescriptions'}',
            AppColors.primary,
          )
        : v.chatOpen(now)
        ? ('Chat with your doctor', AppColors.success)
        : ('View visit', AppColors.inkSoft);
    return SizedBox(
      width: 236,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(v.route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      name: v.doctorName ?? v.specialty,
                      path: v.doctorAvatar,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.doctorLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          Text(
                            v.specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  v.symptoms.trim().isEmpty ? v.specialty : v.symptoms.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                          color: note.$2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      visitWhen(v.at, now: now),
                      style: text.labelSmall?.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every visit: what's coming up or under way first, then past visits by
/// month. Pull to refresh; updates by itself.
class VisitsList extends ConsumerWidget {
  const VisitsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patientVisitsProvider);
    return LiveRefresh(
      onRefresh: () => ref.refresh(patientVisitsProvider.future),
      child: async.when(
        loading: () => const SkeletonList(itemCount: 4),
        error: (e, _) => PullableFill(
          child: ErrorView(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(patientVisitsProvider),
          ),
        ),
        data: (visits) {
          if (visits.isEmpty) {
            return PullableFill(
              child: EmptyView(
                message:
                    'No visits yet.\nEvery consultation you have appears here, '
                    'with the doctor\'s notes and prescriptions.',
                icon: LucideIcons.stethoscope,
                action: FilledButton.icon(
                  icon: const Icon(LucideIcons.video, size: 18),
                  label: const Text('See a doctor'),
                  onPressed: () => context.push('/patient/intake'),
                ),
              ),
            );
          }
          final current = [
            for (final v in visits)
              if (v.isUpcoming || v.isOngoing) v,
          ];
          final past = [
            for (final v in visits)
              if (v.isCompleted) v,
          ];
          var i = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (current.isNotEmpty) ...[
                const MonthHeader('Coming up & in progress'),
                for (final v in current)
                  FadeSlideIn(
                    index: i++,
                    child: VisitCard(visit: v),
                  ),
              ],
              for (final (label, group) in groupByMonth(past, (v) => v.at)) ...[
                MonthHeader(label, count: group.length),
                for (final v in group)
                  FadeSlideIn(
                    index: i++,
                    child: VisitCard(visit: v),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
