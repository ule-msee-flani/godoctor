import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../patient_card/patient_card_sheet.dart';

final _patientNameProvider = FutureProvider.autoDispose
    .family<PatientProfile?, String>(
      (ref, patientId) =>
          ref.watch(profileRepositoryProvider).fetchPatientProfile(patientId),
    );

/// Booked (scheduled) appointments on the doctor's dashboard, soonest first.
class DoctorAppointmentsSection extends ConsumerWidget {
  const DoctorAppointmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-evaluate "can start now" as the clock moves.
    ref.watch(clockTickProvider);
    final async = ref.watch(doctorUpcomingAppointmentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Upcoming appointments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/doctor/schedule'),
              icon: const Icon(LucideIcons.calendarClock, size: 16),
              label: const Text('Manage schedule'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyView(
                message:
                    'No booked appointments yet.\nSet your weekly hours so patients can book you.',
                icon: LucideIcons.calendarDays,
              );
            }
            return Column(
              children: [
                for (final c in list) _AppointmentCard(consultation: c),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AppointmentCard extends ConsumerStatefulWidget {
  const _AppointmentCard({required this.consultation});

  final Consultation consultation;

  @override
  ConsumerState<_AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends ConsumerState<_AppointmentCard> {
  bool _busy = false;

  Consultation get c => widget.consultation;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      if (c.status == ConsultationStatus.scheduled) {
        await ref.read(appointmentRepositoryProvider).start(c.id);
      }
      if (mounted) context.push('/doctor/call/${c.id}');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this appointment?'),
        content: const Text(
          'The patient will be notified and the slot will reopen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel appointment'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(appointmentRepositoryProvider).cancel(c.id);
      ref.invalidate(doctorUpcomingAppointmentsProvider);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final patient = ref.watch(_patientNameProvider(c.patientId)).valueOrNull;
    final live = c.status == ConsultationStatus.inProgress;
    final ready = live || c.canStartNow;
    final when = c.scheduledFor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                ready ? LucideIcons.video : LucideIcons.calendarClock,
                size: 20,
                color: ready ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (patient?.name.isNotEmpty ?? false)
                        ? patient!.name
                        : 'Patient',
                    style: theme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    when == null
                        ? c.specialtyRequested
                        : '${formatDateTime(when)}  ·  ${live ? 'in progress' : formatCountdown(when)}',
                    style: theme.bodySmall,
                  ),
                  if (c.symptomSummary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      c.symptomSummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => showPatientCard(context, c.patientId),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.circleUserRound,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Patient profile',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.labelLarge?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(96, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _busy || !ready ? null : _start,
                  child: Text(live ? 'Open' : 'Start'),
                ),
                if (c.status == ConsultationStatus.scheduled)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: _busy ? null : _cancel,
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
