import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/design_kit.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/appointment_item.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';
import '../widgets/specialty_tiles.dart';

/// Every appointment and visit, newest first. Live.
final myAppointmentsProvider =
    FutureProvider.autoDispose<List<AppointmentItem>>((ref) {
      ref.watch(liveTick(LiveTable.consultations));
      if (ref.watch(currentUserIdProvider) == null) return const [];
      return ref.watch(consultationRepositoryProvider).myAppointments();
    });

/// The ones still to come (soonest first).
List<AppointmentItem> upcomingOf(List<AppointmentItem> all) => [
  for (final a in all)
    if (a.isUpcoming) a,
]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

/// "Starting now", "in 45 min", "in 3 hours", "tomorrow", "in 4 days".
String startsIn(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = at.difference(n);
  if (d.inMinutes <= 5) return 'Starting now';
  if (d.inMinutes < 60) return 'in ${d.inMinutes} min';
  if (d.inHours < 24 && at.day == n.day) {
    return 'in ${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'}';
  }
  final days = DateUtils.dateOnly(at).difference(DateUtils.dateOnly(n)).inDays;
  if (days == 1) return 'tomorrow';
  return 'in $days days';
}

/// Home: "Upcoming appointment" — the doctor's photo melting into a soft
/// card, the time big, and Join when it's time. Swipe for more. Hidden
/// when nothing is booked.
class UpcomingAppointmentsHero extends ConsumerStatefulWidget {
  const UpcomingAppointmentsHero({super.key});

  @override
  ConsumerState<UpcomingAppointmentsHero> createState() =>
      _UpcomingAppointmentsHeroState();
}

class _UpcomingAppointmentsHeroState
    extends ConsumerState<UpcomingAppointmentsHero> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(myAppointmentsProvider).valueOrNull ?? const [];
    final upcoming = upcomingOf(all).take(5).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          upcoming.length == 1
              ? 'Upcoming appointment'
              : 'Upcoming appointments',
          onMore: () => context.push('/patient/appointments'),
          padding: const EdgeInsets.only(left: 20, right: 8),
        ),
        const SizedBox(height: 6),
        SizedBox(
          // Room for a two-line name and the Join button, even with
          // bigger text.
          height: MediaQuery.textScalerOf(context).scale(216).clamp(216, 300),
          child: PageView.builder(
            itemCount: upcoming.length,
            onPageChanged: (p) => setState(() => _page = p),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppointmentHeroCard(item: upcoming[i]),
            ),
          ),
        ),
        if (upcoming.length > 1) ...[
          const SizedBox(height: 10),
          PageDashes(count: upcoming.length, current: _page),
        ],
      ],
    );
  }
}

class AppointmentHeroCard extends ConsumerWidget {
  const AppointmentHeroCard({super.key, required this.item});

  final AppointmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final a = item;
    final now = DateTime.now();
    final join = a.canJoin(now);
    final photo = ref
        .watch(profileRepositoryProvider)
        .avatarUrl(a.doctorAvatar);
    return Pressable(
      child: Material(
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: AppColors.mintGradient),
          child: InkWell(
            onTap: () => context.push(a.route),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 170,
                  child: FadedPhoto(url: photo, name: a.doctorLabel),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 130, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.doctorLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${DateFormat('h:mm a').format(a.startsAt)}, '
                        '${DateFormat('d MMMM').format(a.startsAt)}',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.facility ?? 'Video visit',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        specialtyMetaFor(a.specialty).title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      join
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 38),
                                backgroundColor: AppColors.mint,
                              ),
                              icon: const Icon(LucideIcons.video, size: 16),
                              label: const Text('Join now'),
                              onPressed: () =>
                                  context.push('/patient/appointment/${a.id}'),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.clock,
                                    size: 13,
                                    color: AppColors.mint,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    startsIn(a.startsAt, now: now),
                                    style: text.labelMedium?.copyWith(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }
}

/// All appointments: Upcoming, Completed and Cancelled.
class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAppointmentsProvider);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.go('/patient/doctors'),
          icon: const Icon(LucideIcons.calendarPlus),
          label: const Text('Book'),
        ),
        body: async.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorView(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(myAppointmentsProvider),
          ),
          data: (all) {
            final lists = [
              upcomingOf(all),
              [
                for (final a in all)
                  if (a.isCompleted) a,
              ],
              [
                for (final a in all)
                  if (a.isCancelled) a,
              ],
            ];
            const empty = [
              'Nothing booked. Find a doctor and book a time that suits you.',
              'Your finished visits will show here.',
              'No cancelled appointments.',
            ];
            return TabBarView(
              children: [
                for (var t = 0; t < 3; t++)
                  LiveRefresh(
                    onRefresh: () => ref.refresh(myAppointmentsProvider.future),
                    child: lists[t].isEmpty
                        ? PullableFill(
                            child: EmptyView(
                              message: empty[t],
                              icon: LucideIcons.calendar,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                            itemCount: lists[t].length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              index: i,
                              child: AppointmentTile(item: lists[t][i]),
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppointmentTile extends ConsumerWidget {
  const AppointmentTile({super.key, required this.item});

  final AppointmentItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final a = item;
    final now = DateTime.now();
    final (fg, bg) = switch (a) {
      _ when a.isCancelled => (AppColors.danger, AppColors.dangerSoft),
      _ when a.isCompleted => (AppColors.success, AppColors.successSoft),
      _ when a.canJoin(now) => (AppColors.mint, AppColors.accentTealSoft),
      _ => (AppColors.primary, AppColors.primarySoft),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => context.push(a.route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      name: a.doctorName ?? a.specialty,
                      path: a.doctorAvatar,
                      radius: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.doctorLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            specialtyMetaFor(a.specialty).title,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        a.canJoin(now) && a.isUpcoming
                            ? 'Ready'
                            : a.statusLabel,
                        style: text.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySofter,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.calendar,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          DateFormat('EEE d MMM').format(a.startsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Icon(
                        LucideIcons.clock,
                        size: 15,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          DateFormat('h:mm a').format(a.startsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelLarge,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        a.facility == null
                            ? LucideIcons.video
                            : LucideIcons.hospital,
                        size: 15,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
                if (a.isUpcoming && a.canJoin(now)) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.mint,
                    ),
                    icon: const Icon(LucideIcons.video, size: 18),
                    label: const Text('Join now'),
                    onPressed: () =>
                        context.push('/patient/appointment/${a.id}'),
                  ),
                ] else if (a.isCompleted && a.myRating == null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => context.push(a.route),
                      icon: const Icon(
                        Icons.star_outline_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      label: const Text('Rate this visit'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
