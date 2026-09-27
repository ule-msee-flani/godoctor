import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../consult/consult_flow.dart';
import '../widgets/doctor_widgets.dart';

final publicDoctorProvider = FutureProvider.autoDispose
    .family<PublicDoctor?, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).getDoctor(id),
    );

final doctorReviewsProvider = FutureProvider.autoDispose
    .family<List<DoctorReview>, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).reviews(id),
    );

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

    return Scaffold(
      appBar: AppBar(title: Text(seeNow ? 'Choose a doctor' : 'Doctor')),
      body: doctorAsync.when(
        loading: () => const SkeletonList(itemCount: 3),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(publicDoctorProvider(doctorId)),
        ),
        data: (doctor) {
          if (doctor == null) {
            return const EmptyView(
              message: 'This doctor is not available.',
              icon: LucideIcons.userX,
            );
          }
          return _ProfileBody(doctor: doctor);
        },
      ),
      bottomNavigationBar: doctorAsync.valueOrNull == null
          ? null
          : seeNow
          ? _SeeNowBar(doctor: doctorAsync.value!)
          : _BookBar(doctor: doctorAsync.value!),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.doctor});

  final PublicDoctor doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final reviews = ref.watch(doctorReviewsProvider(doctor.userId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Center(
          child: DoctorAvatar(
            name: doctor.name,
            avatarPath: doctor.avatarPath,
            radius: 48,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                doctor.name,
                textAlign: TextAlign.center,
                style: theme.headlineSmall,
              ),
            ),
            const SizedBox(width: 6),
            const VerifiedBadge(size: 20),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          doctor.specialties.isEmpty
              ? 'General Practice'
              : doctor.specialties.join(' · '),
          textAlign: TextAlign.center,
          style: theme.bodyLarge,
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.shieldCheck, size: 14, color: AppColors.success),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Licence verified by GoDoctor',
                style: TextStyle(color: AppColors.success, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _Stat(
                icon: LucideIcons.briefcaseMedical,
                value: doctor.yearsExperience == null
                    ? '—'
                    : '${doctor.yearsExperience}+ yrs',
                label: 'Experience',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                icon: LucideIcons.star,
                value: doctor.ratingCount == 0
                    ? '—'
                    : doctor.ratingAvg.toStringAsFixed(1),
                label: 'Rating',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                icon: LucideIcons.messageSquareText,
                value: '${doctor.ratingCount}',
                label: 'Reviews',
              ),
            ),
          ],
        ),
        if ((doctor.bio ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('About', style: theme.titleMedium),
          const SizedBox(height: 8),
          _ExpandableText(text: doctor.bio!.trim()),
        ],
        const SizedBox(height: 22),
        Text('Details', style: theme.titleMedium),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(
                  icon: LucideIcons.banknote,
                  label: 'Consultation fee',
                  value: formatKes(doctor.consultationFee),
                ),
                if (doctor.languages.isNotEmpty) ...[
                  const Divider(height: 24),
                  _DetailRow(
                    icon: LucideIcons.languages,
                    label: 'Languages',
                    value: doctor.languages.join(', '),
                  ),
                ],
                const Divider(height: 24),
                _DetailRow(
                  icon: LucideIcons.calendarClock,
                  label: 'Next available',
                  value: doctor.availableNow
                      ? 'Available now'
                      : doctor.nextSlot == null
                      ? 'No open slots'
                      : formatRelativeSlot(doctor.nextSlot!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text('Patient reviews', style: theme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Only patients who completed a consultation can leave a review.',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 10),
        reviews.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LoadingView(),
          ),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No reviews yet.', style: theme.bodyMedium),
              );
            }
            return Column(
              children: [
                for (final r in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReviewCard(review: r),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.ink),
          const SizedBox(height: 6),
          Text(value, style: theme.titleMedium),
          Text(label, style: theme.bodySmall),
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DoctorReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RatingStars(rating: review.rating.toDouble(), size: 15),
                const Spacer(),
                Text(formatDayShort(review.createdAt), style: theme.bodySmall),
              ],
            ),
            if ((review.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment!, style: theme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  LucideIcons.badgeCheck,
                  size: 13,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 4),
                Text('Verified patient', style: theme.bodySmall),
              ],
            ),
          ],
        ),
      ),
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
