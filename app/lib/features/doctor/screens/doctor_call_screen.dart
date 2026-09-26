import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medicine/medicine_gallery.dart';
import '../../patient/family/family_providers.dart';
import '../../prescription/digital_prescription.dart';
import '../widgets/dose_sheet.dart';

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

/// Prescriptions already sent from this consultation (live).
final _sentProvider = StreamProvider.autoDispose
    .family<List<Prescription>, String>(
      (ref, consultationId) => ref
          .watch(prescriptionRepositoryProvider)
          .watchForConsultation(consultationId),
    );

/// The doctor's side of a consultation: the (mock) video call on top -- it
/// can shrink into a floating window -- and underneath, the patient's
/// details, the medicine gallery to prescribe from, and the digital
/// prescription, which is sent to the patient while the call continues.
class DoctorCallScreen extends ConsumerStatefulWidget {
  const DoctorCallScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<DoctorCallScreen> createState() => _DoctorCallScreenState();
}

class _DoctorCallScreenState extends ConsumerState<DoctorCallScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final _tabs = TabController(length: 3, vsync: this);

  /// Medicines chosen but not yet sent.
  final List<PrescriptionItem> _draft = [];
  bool _sending = false;
  bool _finishing = false;
  bool _videoMinimized = false;
  Offset? _pip;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String m, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m), action: action));
  }

  int _draftIndexOf(Drug drug) => _draft.indexWhere((i) => i.drugId == drug.id);

  Future<void> _prescribe(Drug? drug, {int? editIndex}) async {
    final index = editIndex ?? (drug == null ? -1 : _draftIndexOf(drug));
    final item = await showDoseSheet(
      context,
      drug: drug ?? (index >= 0 ? _draft[index].drug : null),
      existing: index >= 0 ? _draft[index] : null,
    );
    if (item == null || !mounted) return;
    setState(() {
      if (index >= 0) {
        _draft[index] = item;
      } else {
        _draft.add(item);
      }
    });
    _toast(
      index >= 0
          ? 'Updated ${item.displayName}'
          : 'Added ${item.displayName} to the prescription',
      action: _tabs.index == 2
          ? null
          : SnackBarAction(label: 'View', onPressed: () => _tabs.animateTo(2)),
    );
  }

  Future<void> _send(String patientName) async {
    setState(() => _sending = true);
    try {
      await ref
          .read(prescriptionRepositoryProvider)
          .issueForConsultation(
            consultationId: widget.consultationId,
            items: List.of(_draft),
          );
      if (!mounted) return;
      setState(_draft.clear);
      _toast('Prescription sent to $patientName');
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _endConsultation() async {
    final unsent = _draft.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this consultation?'),
        content: Text(
          unsent == 0
              ? 'The call ends for both of you. Prescriptions you sent stay with the patient.'
              : 'You have $unsent medicine${unsent == 1 ? '' : 's'} on the prescription that '
                    '${unsent == 1 ? 'has' : 'have'} not been sent. They will be discarded.',
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
      await ref
          .read(consultationRepositoryProvider)
          .completeConsultation(widget.consultationId);
      ref.invalidate(currentDoctorProfileProvider);
      if (mounted) context.go('/doctor');
    } catch (e) {
      if (mounted) {
        _toast('Could not end the consultation: ${friendlyError(e)}');
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

          final patientTab = _PatientTab(
            patient: detail.patient,
            intake: detail.intake,
            consultation: consultation,
          );
          final medicinesTab = _MedicinesTab(
            searchCtrl: _searchCtrl,
            onSearch: (_) => setState(() {}),
            draft: _draft,
            onPrescribe: _prescribe,
          );
          final prescriptionTab = _PrescriptionTab(
            consultationId: widget.consultationId,
            doctorName: doctorName,
            doctorDetail: doctor?.specialties.firstOrNull,
            patientName: patientName,
            draft: _draft,
            sending: _sending,
            onEdit: (i) => _prescribe(null, editIndex: i),
            onRemove: (i) => setState(() => _draft.removeAt(i)),
            onSend: () => _send(patientName),
            onBrowse: () => _tabs.animateTo(1),
          );

          return LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 1000;
              final tabBar = TabBar(
                controller: _tabs,
                tabs: [
                  const Tab(text: 'Patient'),
                  const Tab(text: 'Medicines'),
                  Tab(
                    text: _draft.isEmpty
                        ? 'Prescription'
                        : 'Prescription (${_draft.length})',
                  ),
                ],
              );
              final tabViews = TabBarView(
                controller: _tabs,
                children: [patientTab, medicinesTab, prescriptionTab],
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
            Text(
              (p?.name.isNotEmpty ?? false) ? p!.name : 'Patient',
              style: theme.titleMedium,
            ),
            if (p?.dateOfBirth != null)
              Text(
                '${_age(p!.dateOfBirth!)} years old',
                style: theme.bodySmall,
              ),
            const SizedBox(height: 12),
            _InfoBlock(
              icon: LucideIcons.messageSquareText,
              label: '${consultation.specialtyRequested} · reason for visit',
              value: consultation.symptomSummary,
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
    final color = danger ? AppColors.danger : AppColors.inkFaint;
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

// ---------------------------------------------------------------------------
// Medicines tab
// ---------------------------------------------------------------------------

class _MedicinesTab extends ConsumerWidget {
  const _MedicinesTab({
    required this.searchCtrl,
    required this.onSearch,
    required this.draft,
    required this.onPrescribe,
  });

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final List<PrescriptionItem> draft;
  final Future<void> Function(Drug? drug) onPrescribe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(medicineCatalogProvider);
    final prescribedIds = {
      for (final i in draft)
        if (i.drugId != null) i.drugId!,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: MedicineSearchField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Prescribe a medicine that is not in the list',
                child: OutlinedButton.icon(
                  onPressed: () => onPrescribe(null),
                  icon: const Icon(LucideIcons.pencilLine, size: 16),
                  label: const Text('By name'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: catalog.when(
            loading: () => const MedicineGallerySkeleton(showcaseHeight: 220),
            error: (e, _) => ErrorView(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(medicineCatalogProvider),
            ),
            data: (drugs) => LayoutBuilder(
              builder: (context, c) => MedicineGallery(
                drugs: drugs,
                query: searchCtrl.text,
                markedIds: prescribedIds,
                markIcon: LucideIcons.clipboardCheck,
                markColor: AppColors.primary,
                showcaseHeight: (c.maxHeight * 0.5).clamp(200.0, 290.0),
                emptyMessage: 'The medicine catalogue is empty.',
                footerBuilder: (context, drug) {
                  final line = draft
                      .where((i) => i.drugId == drug.id)
                      .firstOrNull;
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          line == null
                              ? 'Tap Prescribe to choose the dose.'
                              : 'On prescription: ${line.dosage ?? ''} · Qty ${line.quantity}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: line == null
                                    ? AppColors.inkSoft
                                    : AppColors.primaryDark,
                                fontWeight: line == null
                                    ? null
                                    : FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => onPrescribe(drug),
                        icon: Icon(
                          line == null
                              ? LucideIcons.clipboardPlus
                              : LucideIcons.pencil,
                          size: 17,
                        ),
                        label: Text(line == null ? 'Prescribe' : 'Edit dose'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Prescription tab
// ---------------------------------------------------------------------------

class _PrescriptionTab extends ConsumerWidget {
  const _PrescriptionTab({
    required this.consultationId,
    required this.doctorName,
    required this.doctorDetail,
    required this.patientName,
    required this.draft,
    required this.sending,
    required this.onEdit,
    required this.onRemove,
    required this.onSend,
    required this.onBrowse,
  });

  final String consultationId;
  final String doctorName;
  final String? doctorDetail;
  final String patientName;
  final List<PrescriptionItem> draft;
  final bool sending;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final VoidCallback onSend;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final sent = ref.watch(_sentProvider(consultationId)).valueOrNull ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        DigitalPrescription(
          doctorName: doctorName,
          doctorDetail: doctorDetail,
          patientName: patientName,
          items: draft,
          onEditItem: onEdit,
          onRemoveItem: onRemove,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onBrowse,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Add medicine'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: draft.isEmpty || sending ? null : onSend,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.send, size: 16),
                label: Text(
                  sending ? 'Sending…' : 'Send to $patientName',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (sent.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(
                LucideIcons.circleCheck,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sent to the patient (${sent.length})',
                  style: theme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'They can see it now and order the medicines from a chemist.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 12),
          for (final p in sent.reversed) ...[
            DigitalPrescription(
              doctorName: doctorName,
              doctorDetail: doctorDetail,
              patientName: patientName,
              items: p.items,
              issuedAt: p.issuedAt.toLocal(),
              validUntil: p.validUntil,
              reference: p.id,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }
}
