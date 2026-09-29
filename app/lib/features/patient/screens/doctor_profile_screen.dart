import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/profile_hero.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_chemist.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../consult/consult_flow.dart';
import '../specialties/specialty_registry.dart';
import '../widgets/specialty_tiles.dart';
import '../widgets/doctor_widgets.dart';
import '../../reviews/review_widgets.dart';
import '../doctors/my_doctors.dart';

final publicDoctorProvider = FutureProvider.autoDispose
    .family<PublicDoctor?, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).getDoctor(id),
    );

final doctorReviewsProvider = FutureProvider.autoDispose
    .family<List<DoctorReview>, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).reviews(id),
    );

final doctorStatsProvider = FutureProvider.autoDispose
    .family<DoctorPublicStats, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).publicStats(id),
    );

/// A doctor's page, led by their own photo: who they are, what they help
/// with, their track record and what patients say, with booking always at
/// hand.
class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    this.seeNow = false,
  });

  final String doctorId;

  /// Opened from "See a doctor" step 2: the button reserves this doctor and
  /// moves to payment, instead of booking an appointment for later.
  final bool seeNow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorAsync = ref.watch(publicDoctorProvider(doctorId));

    return doctorAsync.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonList(itemCount: 3)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(publicDoctorProvider(doctorId)),
        ),
      ),
      data: (doctor) {
        if (doctor == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              message: 'This doctor is not available.',
              icon: LucideIcons.userX,
            ),
          );
        }
        return ProfileHeroScaffold(
          title: doctor.name,
          photoUrl: ref
              .watch(doctorDirectoryRepositoryProvider)
              .avatarUrl(doctor.avatarPath),
          bottomBar: seeNow
              ? _SeeNowBar(doctor: doctor)
              : _BookBar(doctor: doctor),
          actions: [FavoriteDoctorButton(doctorId: doctor.userId)],
          children: _profile(context, ref, doctor),
        );
      },
    );
  }

  List<Widget> _profile(
    BuildContext context,
    WidgetRef ref,
    PublicDoctor doctor,
  ) {
    final theme = Theme.of(context).textTheme;
    final reviews = ref.watch(doctorReviewsProvider(doctor.userId));
    final stats = ref.watch(doctorStatsProvider(doctor.userId)).valueOrNull;
    final firstName = doctor.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .join(' ');
    final helpsWith = <String>{
      for (final s in doctor.specialties.take(2))
        ...?specialtyContentForSlug(
          specialtyMetaFor(s).slug,
        )?.commonReasons.take(4),
    }.take(6).toList();

    return [
      FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    doctor.name,
                    style: theme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const VerifiedBadge(size: 20),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              doctor.specialties.isEmpty
                  ? 'General Practice'
                  : doctor.specialties.join(' · '),
              style: theme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  leading: doctor.availableNow
                      ? const PulseDot(color: AppColors.success, size: 8)
                      : const Icon(
                          LucideIcons.calendarClock,
                          size: 14,
                          color: AppColors.ink,
                        ),
                  text: doctor.availableNow
                      ? 'Available now'
                      : doctor.nextSlot == null
                      ? 'No open slots'
                      : 'Next: ${formatRelativeSlot(doctor.nextSlot!)}',
                ),
                const _Pill(
                  leading: Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.success,
                  ),
                  text: 'Licence verified',
                ),
                if (doctor.languages.isNotEmpty)
                  _Pill(
                    leading: const Icon(
                      LucideIcons.languages,
                      size: 14,
                      color: AppColors.ink,
                    ),
                    text: doctor.languages.join(', '),
                  ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      FadeSlideIn(
        index: 1,
        child: ProfileStatsRow(
          stats: [
            ProfileStat(
              value: doctor.yearsExperience == null
                  ? 'New'
                  : '${doctor.yearsExperience} yrs',
              label: 'Experience',
            ),
            ProfileStat(
              value: stats == null ? '–' : '${stats.consultations}',
              label: 'Consultations',
            ),
            ProfileStat(
              icon: LucideIcons.star,
              value: doctor.ratingCount == 0
                  ? 'New'
                  : doctor.ratingAvg.toStringAsFixed(1),
              label: doctor.ratingCount == 0
                  ? 'No reviews yet'
                  : '${doctor.ratingCount} reviews',
            ),
          ],
        ),
      ),
      if ((doctor.bio ?? '').trim().isNotEmpty)
        ProfileSection(
          title: 'About $firstName',
          child: _ExpandableText(text: doctor.bio!.trim()),
        ),
      if (helpsWith.isNotEmpty)
        ProfileSection(
          title: 'Can help with',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in helpsWith)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySofter,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    h,
                    style: theme.bodySmall?.copyWith(color: AppColors.ink),
                  ),
                ),
            ],
          ),
        ),
      ProfileSection(
        title: 'Details',
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: LucideIcons.banknote,
                label: 'Video consultation',
                value: formatKes(doctor.consultationFee),
              ),
              if (stats != null && stats.patients > 0) ...[
                const Divider(height: 24),
                _DetailRow(
                  icon: LucideIcons.users,
                  label: 'Patients helped',
                  value: '${stats.patients}',
                ),
              ],
              if (stats?.memberSince != null) ...[
                const Divider(height: 24),
                _DetailRow(
                  icon: LucideIcons.calendarCheck,
                  label: 'On GoDoctor since',
                  value: DateFormat('MMMM yyyy').format(stats!.memberSince!),
                ),
              ],
              const Divider(height: 24),
              const _DetailRow(
                icon: LucideIcons.badgeCheck,
                label: 'Licence',
                value: 'Checked against the KMPDC register',
              ),
            ],
          ),
        ),
      ),
      ProfileSection(
        title: 'What patients say',
        child: ReviewsBlock(
          reviews: reviews,
          average: doctor.ratingAvg,
          count: doctor.ratingCount,
          breakdown: ref
              .watch(ratingBreakdownProvider(doctor.userId))
              .valueOrNull,
          emptyText:
              'No reviews yet. Only patients who completed a consultation can leave one.',
        ),
      ),
    ];
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.leading, required this.text});

  final Widget leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.bodyMedium)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.titleSmall,
          ),
        ),
      ],
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 160;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: (_expanded || !long) ? null : 3,
          overflow: (_expanded || !long)
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (long)
          TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Read more'),
          ),
      ],
    );
  }
}

class _BookBar extends StatelessWidget {
  const _BookBar({required this.doctor});

  final PublicDoctor doctor;

  @override
  Widget build(BuildContext context) {
    final hasSlots = doctor.nextSlot != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Fee', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  formatKes(doctor.consultationFee),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(LucideIcons.calendarPlus, size: 18),
                label: Text(hasSlots ? 'Book appointment' : 'No open slots'),
                onPressed: hasSlots
                    ? () => context.push('/patient/book/${doctor.userId}')
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Step 2 -> 3: reserve this doctor and go to payment.
class _SeeNowBar extends ConsumerStatefulWidget {
  const _SeeNowBar({required this.doctor});

  final PublicDoctor doctor;

  @override
  ConsumerState<_SeeNowBar> createState() => _SeeNowBarState();
}

class _SeeNowBarState extends ConsumerState<_SeeNowBar> {
  bool _busy = false;

  Future<void> _seeNow() async {
    final draft = ref.read(consultDraftProvider);
    if (draft == null) {
      context.push('/patient/intake');
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(consultationRepositoryProvider)
          .requestDoctor(
            doctorId: widget.doctor.userId,
            specialty: draft.specialty,
            symptoms: draft.symptoms,
          );
      // The extras never block the booking.
      final repo = ref.read(consultationRepositoryProvider);
      if (!draft.doctorVideo) {
        await repo
            .setVideoPreference(id, doctorVideo: false)
            .catchError((_) {});
      }
      if (draft.voiceNotePath != null) {
        await repo.attachVoiceNote(id, draft.voiceNotePath!).catchError((_) {});
      }
      if (mounted) context.push('/patient/consult/$id/pay');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      // They may have just gone offline; refresh so the button reflects it.
      ref.invalidate(publicDoctorProvider(widget.doctor.userId));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.doctor;
    final online = doctor.availableNow;
    final firstName = doctor.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  online ? LucideIcons.zap : LucideIcons.circleOff,
                  size: 14,
                  color: online ? AppColors.success : AppColors.inkFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    online ? 'Online now' : 'No longer online',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  formatKes(doctor.consultationFee),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.video, size: 18),
              label: Text(
                online ? 'See $firstName now' : 'Choose another doctor',
              ),
              onPressed: _busy
                  ? null
                  : online
                  ? _seeNow
                  : () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
