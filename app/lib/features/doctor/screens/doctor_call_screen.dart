import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../patient/family/family_providers.dart';
import '../widgets/prescribing.dart';
import '../widgets/visit_summary_editor.dart';
import '../widgets/voice_note_player.dart';
import '../../patient_card/patient_card_sheet.dart';

final _consultationDetailProvider = FutureProvider.autoDispose
    .family<
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

/// The doctor's side of a consultation: the (mock) video call on top -- it
/// can shrink into a floating window -- and underneath, the patient's
/// details, the medicine gallery to prescribe from, the digital
/// prescription (sent while the call continues), and the visit summary the
/// patient keeps afterwards.
class DoctorCallScreen extends ConsumerStatefulWidget {
  const DoctorCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends ConsumerState<DoctorCallScreen>
    with
        SingleTickerProviderStateMixin,
        PrescriptionDrafting<DoctorCallScreen> {
  final _searchCtrl = TextEditingController();
  late final _tabs = TabController(length: 4, vsync: this);
  final _summary = VisitSummaryDraft();
  bool _summaryLoaded = false;
  bool _finishing = false;
  bool _videoMinimized = false;
  Offset? _pip;

  @override
  String get draftConsultationId => widget.consultationId;

  @override
  void initState() {
    super.initState();
    // Tell the patient's waiting room that the doctor is here.
    final repo = ref.read(consultationRepositoryProvider);
    Future.sync(
      () => repo.markDoctorJoined(widget.consultationId),
    ).catchError((_) {});
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabs.dispose();
    _summary.dispose();
    super.dispose();
  }

  @override
  void onDraftChanged(PrescriptionItem item, {required bool updated}) {
    toast(
      updated
          ? 'Updated ${item.displayName}'
          : 'Added ${item.displayName} to the prescription',
      action: _tabs.index == 2
          ? null
          : SnackBarAction(label: 'View', onPressed: () => _tabs.animateTo(2)),
    );
  }

  Future<bool> _saveSummary({bool quiet = false}) async {
    if (!_summary.hasContent) return true;
    try {
      await ref
          .read(consultationRepositoryProvider)
          .saveVisitSummary(
            widget.consultationId,
            summary: _summary.summaryText,
            redFlags: _summary.redFlagsText,
            followUpOn: _summary.followUpOn,
          );
      _summary.markSaved();
      if (!quiet && mounted) toast('Summary saved. The patient will see it.');
      return true;
    } catch (e) {
      if (mounted) toast('Could not save the summary: ${friendlyError(e)}');
      return false;
    }
  }

  Future<void> _endConsultation() async {
    final unsent = draft.length;
    final noSummary = !_summary.hasContent;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this consultation?'),
        content: Text(
          [
            if (unsent == 0)
              'The call ends for both of you. Prescriptions you sent stay with the patient.'
            else
              'You have $unsent medicine${unsent == 1 ? '' : 's'} on the prescription that '
                  '${unsent == 1 ? 'has' : 'have'} not been sent. They will be discarded.',
            if (noSummary)
              'Tip: a short visit summary (Summary tab) helps the patient remember what you said.',
            'The patient can message you free for 24 hours after this.',
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep talking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End consultation'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _finishing = true);
    try {
      if (_summary.dirty) await _saveSummary(quiet: true);
      await ref
          .read(consultationRepositoryProvider)
          .completeConsultation(widget.consultationId);
      ref.invalidate(currentDoctorProfileProvider);
      if (mounted) context.go('/doctor');
    } catch (e) {
      if (mounted) {
        toast('Could not end the consultation: ${friendlyError(e)}');
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
    final doctor = ref.watch(currentDoctorProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: _finishing ? null : _endConsultation,
              icon: const Icon(LucideIcons.phoneOff, size: 16),
              label: Text(_finishing ? 'Ending…' : 'End'),
            ),
          ),
        ],
      ),
      body: detailAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (detail) {
          final consultation = detail.consultation;
          if (consultation == null) {
            return const ErrorView(message: 'Consultation not found');
          }
          if (!_summaryLoaded) {
            _summaryLoaded = true;
            _summary.load(consultation);
          }
          final patientName = (detail.patient?.name.isNotEmpty ?? false)
              ? detail.patient!.name
              : 'Patient';
          // Family members the patient brought into the call.
          final listeners = <String>[
            for (final p
                in ref
                        .watch(sessionPeopleProvider(widget.consultationId))
                        .valueOrNull ??
                    const [])
              if (p.isFamily && p.isJoined) p.name,
          ];
          final doctorName = (doctor?.name.isNotEmpty ?? false)
              ? (doctor!.name.startsWith('Dr')
                    ? doctor.name
                    : 'Dr ${doctor.name}')
              : 'Your doctor';
          // The patient asked for the doctor's camera to stay off (data).
          final myCameraOff = !consultation.doctorVideoPreferred;

          final patientTab = _PatientTab(
            patient: detail.patient,
            intake: detail.intake,
            consultation: consultation,
          );
          final medicinesTab = PrescribeMedicinesPanel(
            searchCtrl: _searchCtrl,
            onSearch: (_) => setState(() {}),
            draft: draft,
            onPrescribe: (drug, {template}) =>
                prescribe(drug, template: template),
          );
          final prescriptionTab = PrescriptionDraftPanel(
            consultationId: widget.consultationId,
            doctorName: doctorName,
            doctorDetail: doctor?.specialties.firstOrNull,
            patientName: patientName,
            patientAge: detail.patient?.ageOn(DateTime.now()),
            patientGender: detail.patient?.genderLabel,
            draft: draft,
            sending: sending,
            onEdit: (i) => prescribe(null, editIndex: i),
            onRemove: (i) => setState(() => draft.removeAt(i)),
            onSend: () => sendDraft(patientName),
            onBrowse: () => _tabs.animateTo(1),
          );
          final summaryTab = VisitSummaryEditor(
            draft: _summary,
            patientName: patientName,
            onSave: _saveSummary,
          );

          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final tabBar = TabBar(
                controller: _tabs,
                isScrollable: c.maxWidth < 420,
                tabAlignment: c.maxWidth < 420 ? TabAlignment.start : null,
                tabs: [
                  const Tab(text: 'Patient'),
                  const Tab(text: 'Medicines'),
                  Tab(
                    text: draft.isEmpty
                        ? 'Prescription'
                        : 'Prescription (${draft.length})',
                  ),
                  const Tab(text: 'Summary'),
                ],
              );
              final tabViews = TabBarView(
                controller: _tabs,
                children: [
                  patientTab,
                  medicinesTab,
                  prescriptionTab,
                  summaryTab,
                ],
              );

              if (wide) {
                // Desktop: video + patient on the left, work on the right.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 420,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          VideoCallPanel(
                            otherPartyName: patientName,
                            otherPartyRole: 'Patient',
                            listeners: listeners,
                            startedAt: consultation.startedAt,
                            startWithCameraOff: myCameraOff,
                            onEndCall: _endConsultation,
                          ),
                          const SizedBox(height: 16),
                          _PatientSummary(
                            patient: detail.patient,
                            intake: detail.intake,
                            consultation: consultation,
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          tabBar,
                          Expanded(child: tabViews),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Phone / tablet: video on top (or floating), tabs below.
              final videoHeight = (c.maxHeight * 0.32).clamp(170.0, 260.0);
              const pipW = 132.0, pipH = 176.0;
              final pip =
                  _pip ?? Offset(c.maxWidth - pipW - 12, c.maxHeight * 0.35);

              return Stack(
                children: [
                  Column(
                    children: [
                      if (!_videoMinimized)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: VideoCallPanel(
                            otherPartyName: patientName,
                            otherPartyRole: 'Patient',
                            listeners: listeners,
                            startedAt: consultation.startedAt,
                            height: videoHeight,
                            startWithCameraOff: myCameraOff,
                            onEndCall: _endConsultation,
                            onMinimize: () =>
                                setState(() => _videoMinimized = true),
                          ),
                        ),
                      tabBar,
                      Expanded(child: tabViews),
                    ],
                  ),
                  if (_videoMinimized)
                    Positioned(
                      left: pip.dx,
                      top: pip.dy,
                      child: GestureDetector(
                        onPanUpdate: (d) => setState(() {
                          final next = pip + d.delta;
                          _pip = Offset(
                            next.dx.clamp(0, c.maxWidth - pipW),
                            next.dy.clamp(0, c.maxHeight - pipH),
                          );
                        }),
                        child: VideoCallPanel(
                          otherPartyName: patientName,
                          startedAt: consultation.startedAt,
                          compact: true,
                          onEndCall: _endConsultation,
                          onExpand: () =>
                              setState(() => _videoMinimized = false),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Patient tab
// ---------------------------------------------------------------------------

class _PatientTab extends StatelessWidget {
  const _PatientTab({
    required this.patient,
    required this.intake,
    required this.consultation,
  });

  final PatientProfile? patient;
  final IntakeForm? intake;
  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PatientSummary(
          patient: patient,
          intake: intake,
          consultation: consultation,
        ),
      ],
    );
  }
}

class _PatientSummary extends StatelessWidget {
  const _PatientSummary({
    required this.patient,
    required this.intake,
    required this.consultation,
  });

  final PatientProfile? patient;
  final IntakeForm? intake;
  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final p = patient;
    String? nonEmpty(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final allergies = nonEmpty(p?.allergies);
    final conditions = nonEmpty(p?.chronicConditions);
    final meds = nonEmpty(p?.currentMedications);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PatientRow(
              patientId: consultation.patientId,
              fallbackName: (p?.name.isNotEmpty ?? false) ? p!.name : 'Patient',
            ),
            if (p?.dateOfBirth != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_age(p!.dateOfBirth!)} years old',
                  style: theme.bodySmall,
                ),
              ),
            if (!consultation.doctorVideoPreferred) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySofter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.videoOff,
                      size: 16,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The patient asked for your camera to be off to save '
                        'their data. Switch it on if you need to show something.',
                        style: theme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _InfoBlock(
              icon: LucideIcons.messageSquareText,
              label: '${consultation.specialtyRequested} · reason for visit',
              value: consultation.symptomSummary,
            ),
            if (intake?.voiceNotePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: VoiceNotePlayer(path: intake!.voiceNotePath!),
              ),
            if (intake?.duration != null || intake?.severity != null)
              _InfoBlock(
                icon: LucideIcons.clock3,
                label: 'Duration / severity',
                value: [
                  if (intake?.duration != null) intake!.duration!,
                  if (intake?.severity != null) intake!.severity!,
                ].join(' · '),
              ),
            _InfoBlock(
              icon: LucideIcons.triangleAlert,
              label: 'Allergies',
              value: allergies ?? 'None recorded',
              danger: allergies != null,
            ),
            _InfoBlock(
              icon: LucideIcons.heartPulse,
              label: 'Chronic conditions',
              value: conditions ?? 'None recorded',
            ),
            _InfoBlock(
              icon: LucideIcons.pill,
              label: 'Current medication',
              value: meds ?? 'None recorded',
            ),
          ],
        ),
      ),
    );
  }

  static int _age(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    // Allergies stay red: there the colour is a warning, not decoration.
    final color = danger ? AppColors.danger : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.bodySmall),
                Text(
                  value,
                  style: theme.bodyMedium?.copyWith(
                    color: danger ? AppColors.danger : AppColors.ink,
                    fontWeight: danger ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
