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
import 'package:flutter/services.dart';
import '../../call/active_call.dart';
import '../../call/call_stage.dart';

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

/// The doctor's visit notes, per consultation, kept while they step away
/// from the call (it carries on in a floating window).
final _summaries = <String, VisitSummaryDraft>{};

/// The doctor's side of a consultation: the (mock) video call full screen,
/// and a panel pulled up from the bottom with the patient's details, the
/// medicine gallery to prescribe from, the digital prescription (sent while
/// the call continues), and the visit summary the patient keeps afterwards.
/// Back shrinks the call into a floating window; it carries on.
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
  late final VisitSummaryDraft _summary;
  late bool _summaryLoaded;
  bool _finishing = false;
  late final ActiveCallController _calls;

  /// Ended on purpose: don't keep the call floating. Minimized: don't pull
  /// it back full screen.
  bool _leaving = false;
  bool _minimized = false;

  @override
  String get draftConsultationId => widget.consultationId;

  @override
  void initState() {
    super.initState();
    _calls = ref.read(activeCallProvider.notifier);
    _summaryLoaded = _summaries.containsKey(widget.consultationId);
    _summary = _summaries.putIfAbsent(
      widget.consultationId,
      VisitSummaryDraft.new,
    );
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
    // The summary draft stays in _summaries until the visit ends.
    if (!_leaving) {
      final calls = _calls;
      final id = widget.consultationId;
      Future.microtask(() => calls.screenClosed(id));
    }
    super.dispose();
  }

  /// Back (or "<"): the call carries on in a floating window.
  void _minimize() {
    if (_minimized) return;
    HapticFeedback.selectionClick();
    _minimized = true;
    _calls.minimize();
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/doctor');
    }
  }

  void _sync(ActiveCall info) {
    if (_leaving || _minimized) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_leaving && !_minimized) _calls.showing(info);
    });
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
      _leaving = true;
      _calls.end(widget.consultationId);
      PrescriptionDraftStore.clear(widget.consultationId);
      _summaries.remove(widget.consultationId);
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
    final call = ref.watch(activeCallProvider);
    final mine = call?.consultationId == widget.consultationId ? call : null;

    final detail = detailAsync.valueOrNull;
    final consultation = detail?.consultation;
    if (detail == null || consultation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Consultation')),
        body: detailAsync.hasError
            ? ErrorView(message: friendlyError(detailAsync.error!))
            : detail != null
            ? const ErrorView(message: 'Consultation not found')
            : const LoadingView(),
      );
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
        ? (doctor!.name.startsWith('Dr') ? doctor.name : 'Dr ${doctor.name}')
        : 'Your doctor';
    // The patient asked for the doctor's camera to stay off (data).
    final myCameraOff = !consultation.doctorVideoPreferred;
    final myPhoto = ref
        .watch(doctorDirectoryRepositoryProvider)
        .avatarUrl(ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl);

    _sync(
      ActiveCall(
        consultationId: widget.consultationId,
        isDoctor: true,
        otherName: patientName,
        otherRole: 'Patient',
        selfPhotoUrl: myPhoto,
        startedAt: consultation.startedAt,
        cameraOff: myCameraOff,
      ),
    );

    final patientTab = _PatientTab(
      patient: detail.patient,
      intake: detail.intake,
      consultation: consultation,
    );
    final medicinesTab = PrescribeMedicinesPanel(
      searchCtrl: _searchCtrl,
      onSearch: (_) => setState(() {}),
      draft: draft,
      onPrescribe: (drug, {template}) => prescribe(drug, template: template),
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

    Widget video({
      double topInset = 0,
      double radius = 26,
      bool? panelOpen,
      VoidCallback? togglePanel,
    }) => VideoCallPanel(
      otherPartyName: patientName,
      otherPartyRole: 'Patient',
      listeners: listeners,
      startedAt: consultation.startedAt,
      startWithCameraOff: myCameraOff,
      selfPhotoUrl: myPhoto,
      radius: radius,
      topInset: topInset,
      onBack: _minimize,
      muted: mine?.muted,
      onToggleMute: mine == null ? null : _calls.toggleMute,
      cameraOff: mine?.cameraOff,
      onCameraChanged: mine == null ? null : _calls.setCameraOff,
      speakerOn: mine?.speakerOn,
      onToggleSpeaker: mine == null ? null : _calls.toggleSpeaker,
      onPanel: togglePanel,
      panelOpen: panelOpen ?? false,
      onEndCall: _finishing ? null : _endConsultation,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _minimize();
      },
      child: LayoutBuilder(
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
            children: [patientTab, medicinesTab, prescriptionTab, summaryTab],
          );

          if (wide) {
            // Desktop: video + patient on the left, work on the right.
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
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        video(),
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
              ),
            );
          }

          // Phone / tablet: the call full screen; the work is in the panel
          // pulled up from the bottom (open to start with).
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Scaffold(
              backgroundColor: AppColors.ink,
              body: CallStage(
                initiallyOpen: true,
                panelTitle: draft.isEmpty
                    ? 'Patient, prescribing & notes'
                    : 'Prescribing · ${draft.length} not sent',
                panelIcon: LucideIcons.stethoscope,
                video:
                    (
                      context, {
                      required panelOpen,
                      required togglePanel,
                      required topInset,
                    }) => video(
                      topInset: topInset,
                      radius: 0,
                      panelOpen: panelOpen,
                      togglePanel: togglePanel,
                    ),
                panel: Column(
                  children: [
                    tabBar,
                    Expanded(child: tabViews),
                  ],
                ),
              ),
            ),
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
