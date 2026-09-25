import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/repository_providers.dart';
import '../widgets/prescription_builder.dart';

final _consultationDetailProvider =
    FutureProvider.family<
      ({
        Consultation? consultation,
        IntakeForm? intake,
        PatientProfile? patient,
      }),
      String
    >((ref, consultationId) async {
      final consultationRepo = ref.watch(consultationRepositoryProvider);
      final consultation = await consultationRepo.fetchById(consultationId);
      final intake = await consultationRepo.fetchIntakeForm(consultationId);
      final patient = consultation == null
          ? null
          : await ref
                .watch(profileRepositoryProvider)
                .fetchPatientProfile(consultation.patientId);
      return (consultation: consultation, intake: intake, patient: patient);
    });

class DoctorCallScreen extends ConsumerStatefulWidget {
  const DoctorCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends ConsumerState<DoctorCallScreen> {
  final _notesCtrl = TextEditingController();
  List<PrescriptionItem> _items = [];
  bool _finishing = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishConsultation(String patientId) async {
    setState(() => _finishing = true);
    try {
      if (_items.isNotEmpty) {
        await ref
            .read(prescriptionRepositoryProvider)
            .issuePrescription(
              patientId: patientId,
              consultationId: widget.consultationId,
              items: _items,
            );
      }
      await ref
          .read(consultationRepositoryProvider)
          .completeConsultation(widget.consultationId);
      if (mounted) context.go('/doctor');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not finish: $e')));
      }
    } finally {
      if (mounted) setState(() => _finishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      _consultationDetailProvider(widget.consultationId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Consultation')),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: '$e'),
          data: (detail) {
            if (detail.consultation == null) {
              return const ErrorView(message: 'Consultation not found');
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 900;
                final videoAndInfo = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoCallPanel(
                      otherPartyName: detail.patient?.name ?? 'patient',
                      onEndCall: () {},
                    ),
                    const SizedBox(height: 16),
                    _PatientInfoCard(
                      patient: detail.patient,
                      intake: detail.intake,
                      consultation: detail.consultation!,
                    ),
                  ],
                );
                final notesAndRx = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText:
                                'Clinical notes (not shared with patient)...',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Prescription',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        PrescriptionBuilder(
                          items: _items,
                          onChanged: (items) => setState(() => _items = items),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(
                            _finishing ? 'Finishing...' : 'Finish consultation',
                          ),
                          onPressed: _finishing
                              ? null
                              : () => _finishConsultation(
                                  detail.consultation!.patientId,
                                ),
                        ),
                      ],
                    ),
                  ),
                );

                final content = wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: videoAndInfo),
                          const SizedBox(width: 16),
                          Expanded(child: notesAndRx),
                        ],
                      )
                    : Column(
                        children: [
                          videoAndInfo,
                          const SizedBox(height: 16),
                          notesAndRx,
                        ],
                      );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: content,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  const _PatientInfoCard({
    required this.patient,
    required this.intake,
    required this.consultation,
  });

  final PatientProfile? patient;
  final IntakeForm? intake;
  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patient?.name ?? 'Patient',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (patient?.allergies != null && patient!.allergies!.isNotEmpty)
              Text('Allergies: ${patient!.allergies}'),
            if (patient?.chronicConditions != null &&
                patient!.chronicConditions!.isNotEmpty)
              Text('Chronic conditions: ${patient!.chronicConditions}'),
            const Divider(),
            Text('Reason: ${consultation.symptomSummary}'),
            if (intake?.duration != null) Text('Duration: ${intake!.duration}'),
            if (intake?.severity != null) Text('Severity: ${intake!.severity}'),
          ],
        ),
      ),
    );
  }
}
