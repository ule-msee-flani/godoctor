import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../prescription/digital_prescription.dart';
import '../../prescription/suggested_chemist_card.dart';
import '../family/family_providers.dart';
import '../family/family_session_panel.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;

/// Prescriptions from this consultation, appearing live as the doctor
/// sends them.
final consultationPrescriptionsProvider = StreamProvider.autoDispose
    .family<List<Prescription>, String>(
      (ref, consultationId) => ref
          .watch(prescriptionRepositoryProvider)
          .watchForConsultation(consultationId),
    );

/// The patient's side of the consultation: the (mock) video call on top and,
/// below it, any prescription the doctor sends -- with a suggested chemist
/// to order the medicines from, all while the call carries on.
class PatientCallScreen extends ConsumerWidget {
  const PatientCallScreen({super.key, required this.consultationId});

  final String consultationId;

  Future<void> _leave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave the call?'),
        content: const Text(
          'You can come back to it from Activity while the doctor is still on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final consultation = ref.watch(appointmentProvider(consultationId)).value;
    final doctor = consultation?.doctorId == null
        ? null
        : ref.watch(publicDoctorProvider(consultation!.doctorId!)).value;
    final prescriptions =
        ref.watch(consultationPrescriptionsProvider(consultationId)).value ??
        const <Prescription>[];
    final patient = ref.watch(currentPatientProfileProvider).value;

    final ended = consultation?.status == ConsultationStatus.completed;
    final listeners = <String>[
      for (final p
          in ref.watch(sessionPeopleProvider(consultationId)).valueOrNull ??
              const [])
        if (p.isFamily && p.isJoined) p.name,
    ];
    final doctorName = doctor?.name ?? 'Your doctor';
    final patientName = (patient?.name.isNotEmpty ?? false)
        ? patient!.name
        : 'You';

    return Scaffold(
      appBar: AppBar(
        title: Text(ended ? 'Consultation ended' : 'Consultation'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final videoHeight = (c.maxHeight * 0.36).clamp(190.0, 300.0);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (ended)
                _EndedBanner(onDone: () => context.pop())
              else
                VideoCallPanel(
                  otherPartyName: doctorName,
                  otherPartyRole: consultation?.specialtyRequested,
                  startedAt: consultation?.startedAt,
                  height: videoHeight,
                  listeners: listeners,
                  onEndCall: () => _leave(context),
                ),
              if (!ended) ...[
                const SizedBox(height: 16),
                FamilySessionPanel(consultationId: consultationId),
              ],
              const SizedBox(height: 20),
              if (prescriptions.isEmpty)
                _NoPrescriptionYet(ended: ended)
              else ...[
                Row(
                  children: [
                    const Icon(
                      LucideIcons.fileCheck,
                      size: 18,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prescriptions.length == 1
                            ? 'Your prescription'
                            : 'Your prescriptions (${prescriptions.length})',
                        style: theme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final p in prescriptions.reversed) ...[
                  DigitalPrescription(
                    doctorName: doctorName,
                    doctorDetail: consultation?.specialtyRequested,
                    patientName: patientName,
                    items: p.items,
                    issuedAt: p.issuedAt.toLocal(),
                    validUntil: p.validUntil,
                    reference: p.id,
                  ),
                  const SizedBox(height: 12),
                  SuggestedChemistCard(prescription: p),
                  const SizedBox(height: 24),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _NoPrescriptionYet extends StatelessWidget {
  const _NoPrescriptionYet({required this.ended});

  final bool ended;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: const Icon(
              LucideIcons.fileText,
              color: AppColors.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              ended
                  ? 'Your doctor did not send a prescription for this consultation.'
                  : 'If your doctor prescribes medicine, the prescription appears here '
                        'during the call, and you can order it straight away.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedBanner extends StatelessWidget {
  const _EndedBanner({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleCheck, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'The doctor ended the consultation.',
              style: theme.titleSmall,
            ),
          ),
          TextButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
