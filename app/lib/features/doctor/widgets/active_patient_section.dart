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
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

final _activeConsultsProvider = StreamProvider.autoDispose
    .family<List<Consultation>, String>(
      (ref, doctorId) => ref
          .watch(consultationRepositoryProvider)
          .watchActiveForDoctor(doctorId),
    );

final _patientProvider = FutureProvider.autoDispose
    .family<PatientProfile?, String>(
      (ref, id) => ref.watch(profileRepositoryProvider).fetchPatientProfile(id),
    );

/// Live "Your patient" panel on the doctor dashboard. When a patient chooses
/// this doctor the card appears immediately with "paying now"; the moment the
/// payment lands it switches to "Join consultation".
class ActivePatientSection extends ConsumerWidget {
  const ActivePatientSection({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_activeConsultsProvider(doctorId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your patient', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        async.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyView(
                message:
                    'No patient right now.\nWhile you are available, patients can choose you and you will see them here.',
                icon: LucideIcons.userRound,
              );
            }
            return Column(
              children: [for (final c in list) _PatientCard(consultation: c)],
            );
          },
        ),
      ],
    );
  }
}

class _PatientCard extends ConsumerWidget {
  const _PatientCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final c = consultation;
    final patient = ref.watch(_patientProvider(c.patientId)).valueOrNull;
    final name = (patient?.name.isNotEmpty ?? false)
        ? patient!.name
        : 'Your patient';
    final paying = c.status == ConsultationStatus.awaitingPayment;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: paying ? AppColors.warningSoft : AppColors.successSoft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (paying)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                else
                  const Icon(
                    LucideIcons.circleCheck,
                    color: AppColors.success,
                    size: 20,
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    paying
                        ? '$name chose you and is paying now'
                        : '$name has paid',
                    style: theme.titleSmall,
                  ),
                ),
                if (c.feeAmount != null && c.feeAmount! > 0)
                  Text(formatKes(c.feeAmount), style: theme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${c.specialtyRequested}: "${c.symptomSummary}"',
              style: theme.bodyMedium,
            ),
            if ((patient?.allergies ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Allergies: ${patient!.allergies}',
                      style: theme.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (paying)
              Text(
                c.paymentDueAt == null
                    ? 'Stay online: the consultation starts as soon as they pay.'
                    : 'Stay online: the consultation starts as soon as they pay '
                          '(reserved until ${formatTime(c.paymentDueAt!)}).',
                style: theme.bodySmall,
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => context.push('/doctor/call/${c.id}'),
                icon: const Icon(LucideIcons.video, size: 18),
                label: const Text('Join consultation'),
              ),
          ],
        ),
      ),
    );
  }
}
