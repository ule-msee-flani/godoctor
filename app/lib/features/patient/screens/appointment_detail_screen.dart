import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/doctor_widgets.dart';
import '../widgets/review_sheet.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-evaluate time-dependent state (the Join button) as time passes.
    ref.watch(clockTickProvider);
    final async = ref.watch(appointmentProvider(consultationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: async.when(
        loading: () => const SkeletonList(itemCount: 3),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (c) {
          if (c == null) {
            return const ErrorView(message: 'Appointment not found');
          }
          return _Body(consultation: c);
        },
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.consultation});

  final Consultation consultation;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;

  Consultation get c => widget.consultation;

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      if (c.status == ConsultationStatus.scheduled) {
        await ref.read(appointmentRepositoryProvider).start(c.id);
      }
      if (mounted) context.push('/patient/call/${c.id}');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: const Text(
          'The doctor will be notified and the time slot will be released.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(appointmentRepositoryProvider).cancel(c.id);
      ref.invalidate(upcomingAppointmentsProvider);
      if (mounted) _toast('Appointment cancelled');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final doctorAsync = c.doctorId == null
        ? null
        : ref.watch(publicDoctorProvider(c.doctorId!));
    final doctor = doctorAsync?.valueOrNull;
    final start = c.scheduledFor;

    final isUpcoming = c.status == ConsultationStatus.scheduled;
    final isLive = c.status == ConsultationStatus.inProgress;
    final isDone = c.status == ConsultationStatus.completed;
    final isCancelled = c.status == ConsultationStatus.cancelled;

    final (label, bg, fg) = switch (c.status) {
      ConsultationStatus.scheduled => (
        'Upcoming',
        AppColors.primarySoft,
        AppColors.primary,
      ),
      ConsultationStatus.inProgress => (
        'In progress',
        AppColors.successSoft,
        AppColors.success,
      ),
      ConsultationStatus.completed => (
        'Completed',
        AppColors.successSoft,
        AppColors.success,
      ),
      ConsultationStatus.cancelled => (
        'Cancelled',
        AppColors.border,
        AppColors.inkSoft,
      ),
      _ => (c.status.name, AppColors.border, AppColors.inkSoft),
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isCancelled ? null : AppColors.primaryGradient,
            color: isCancelled ? AppColors.border : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? bg
                      : Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isCancelled ? fg : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                start == null
                    ? 'On-demand consultation'
                    : formatDateTime(start),
                style: theme.headlineSmall?.copyWith(
                  color: isCancelled ? AppColors.inkSoft : Colors.white,
                ),
              ),
              if (start != null && isUpcoming) ...[
                const SizedBox(height: 4),
                Text(
                  'Starts ${formatCountdown(start)}',
                  style: theme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (doctor != null)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/patient/doctor/${doctor.userId}'),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    DoctorAvatar(
                      name: doctor.name,
                      avatarPath: doctor.avatarPath,
                      radius: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  doctor.name,
                                  style: theme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const VerifiedBadge(),
                            ],
                          ),
                          Text(c.specialtyRequested, style: theme.bodySmall),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.inkFaint,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (start != null && c.scheduledEnd != null) ...[
                  _Row(
                    icon: LucideIcons.clock,
                    label: 'Duration',
                    value:
                        '${c.scheduledEnd!.difference(start).inMinutes} minutes',
                  ),
                  const Divider(height: 22),
                ],
                _Row(
                  icon: LucideIcons.banknote,
                  label: 'Fee',
                  value: formatKes(c.feeAmount),
                ),
                if (c.symptomSummary.isNotEmpty) ...[
                  const Divider(height: 22),
                  Text('Reason for visit', style: theme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    c.symptomSummary,
                    style: theme.bodyLarge?.copyWith(color: AppColors.ink),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isUpcoming || isLive) ...[
          FilledButton.icon(
            icon: const Icon(LucideIcons.video, size: 18),
            label: Text(
              isLive || c.canStartNow ? 'Join call' : 'Opens 10 minutes before',
            ),
            onPressed: _busy || !(isLive || c.canStartNow) ? null : _join,
          ),
        ],
        if (isUpcoming) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.calendarClock, size: 18),
            label: const Text('Reschedule'),
            onPressed: _busy || c.doctorId == null
                ? null
                : () => context.push(
                    '/patient/book/${c.doctorId}?reschedule=${c.id}',
                  ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(LucideIcons.calendarX, size: 18),
            label: const Text('Cancel appointment'),
            onPressed: _busy ? null : _cancel,
          ),
        ],
        if (isDone) ...[
          FilledButton.icon(
            icon: const Icon(LucideIcons.fileText, size: 18),
            label: const Text('View prescription'),
            onPressed: () => context.push('/patient/prescriptions'),
          ),
          const SizedBox(height: 10),
          ReviewPrompt(
            consultationId: c.id,
            doctorName: doctor?.name ?? 'your doctor',
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: theme.bodyMedium)),
        Text(value, style: theme.titleSmall),
      ],
    );
  }
}
