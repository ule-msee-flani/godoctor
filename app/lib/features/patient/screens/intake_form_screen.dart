import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/data_saver.dart';
import '../../../services/emergency_check.dart';
import '../consult/consult_flow.dart';
import '../consult/voice_note_recorder.dart';
import '../home/emergency_strip.dart';
import '../widgets/emergency_stop_view.dart';
import '../widgets/specialty_tiles.dart';
import '../intake/body_map.dart';

/// "See a doctor", step 1 of 3: pick the kind of problem and describe it in
/// your own words. Then step 2 lists the doctors who are online for it.
class IntakeFormScreen extends ConsumerStatefulWidget {
  const IntakeFormScreen({
    super.key,
    this.initialSpecialty,
    this.initialSymptoms,
  });

  /// Pre-selected from the home search / specialty pages.
  final String? initialSpecialty;
  final String? initialSymptoms;

  @override
  ConsumerState<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends ConsumerState<IntakeFormScreen> {
  String? _specialty;

  /// Body areas tapped on the map, in order.
  final List<String> _areas = [];
  bool _showMap = false;
  bool _specialtyChosen = false;

  /// What the doctor reads: where it hurts, then their own words.
  String get _symptomText => [
    if (_areas.isNotEmpty) 'Where: ${describeAreas(_areas)}.',
    _symptomsCtrl.text.trim(),
  ].where((s) => s.isNotEmpty).join(' ');

  void _areasChanged(List<String> next) {
    setState(() {
      _areas
        ..clear()
        ..addAll(next);
      var s = specialtyForAreas(next);
      final gender = ref
          .read(currentPatientProfileProvider)
          .valueOrNull
          ?.gender;
      if (s == 'Obstetrics & Gynaecology' && gender == 'male') {
        s = 'General Practice';
      }
      if (s != null && !_specialtyChosen) _specialty = s;
    });
  }

  late final _symptomsCtrl = TextEditingController(
    text: widget.initialSymptoms,
  );
  EmergencyCheckResult? _emergencyResult;
  VoiceRecording? _voice;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(consultDraftProvider);
    final initial = widget.initialSpecialty ?? draft?.specialty;
    if (initial != null && kSpecialties.contains(initial)) _specialty = initial;
    if (widget.initialSymptoms == null && draft != null) {
      _symptomsCtrl.text = draft.symptoms;
    }
  }

  @override
  void dispose() {
    _symptomsCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _specialty != null &&
      (_symptomsCtrl.text.trim().length >= 3 || _areas.isNotEmpty);

  Future<void> _findDoctor() async {
    final symptoms = _symptomText;
    final emergency = checkForEmergency([symptoms]);

    if (emergency.flagged) {
      setState(() => _emergencyResult = emergency);
      // Recorded for audit even though nothing is sent to a doctor.
      try {
        await ref
            .read(consultationRepositoryProvider)
            .requestConsultation(
              specialty: _specialty!,
              symptomSummary: symptoms,
              symptoms: symptoms,
              flaggedEmergency: true,
            );
      } catch (_) {}
      return;
    }

    // Upload the voice note now so the doctor can play it before the call.
    String? voicePath;
    final voice = _voice;
    final userId = ref.read(currentUserIdProvider);
    if (voice != null && userId != null) {
      setState(() => _uploading = true);
      try {
        voicePath = await ref
            .read(consultationRepositoryProvider)
            .uploadVoiceNote(
              patientId: userId,
              bytes: voice.bytes,
              fileExt: voice.fileExt,
              contentType: voice.contentType,
            );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The voice note couldn\'t be sent. Your written description will still reach the doctor.',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (!mounted) return;

    ref.read(consultDraftProvider.notifier).state = ConsultDraft(
      specialty: _specialty!,
      symptoms: symptoms,
      voiceNotePath: voicePath,
      doctorVideo: !ref.read(dataSaverProvider),
    );
    context.push('/patient/consult/doctors');
  }

  @override
  Widget build(BuildContext context) {
    if (_emergencyResult != null) {
      return EmergencyStopView(
        matchedKeyword: _emergencyResult!.matchedKeyword,
      );
    }
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('See a doctor')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ConsultSteps(current: 1),
                    const SizedBox(height: 20),
                    _WhereItHurts(
                      open: _showMap,
                      picked: _areas,
                      female:
                          ref
                              .watch(currentPatientProfileProvider)
                              .valueOrNull
                              ?.gender ==
                          'female',
                      onOpen: () => setState(() => _showMap = !_showMap),
                      onChanged: _areasChanged,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'What do you need help with?',
                      style: theme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose the closest match. Not sure? Pick General.',
                      style: theme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    SpecialtyGrid(
                      selected: _specialty ?? '',
                      onSelected: (v) => setState(() {
                        _specialty = v;
                        _specialtyChosen = true;
                      }),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.notebookPen,
                          size: 16,
                          color: AppColors.ink,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Describe it in your own words',
                            style: theme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _symptomsCtrl,
                      maxLines: 5,
                      maxLength: 600,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'What is bothering you, when did it start, and has anything helped?',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    Text(
                      'Your doctor reads this before the consultation starts.',
                      style: theme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    VoiceNoteRecorder(
                      onChanged: (v) => setState(() => _voice = v),
                    ),
                    const SizedBox(height: 24),
                    const EmergencyStrip(),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: FilledButton.icon(
                icon: const Icon(LucideIcons.search, size: 18),
                onPressed: _canContinue && !_uploading ? _findDoctor : null,
                label: Text(
                  _specialty == null
                      ? 'Choose a category first'
                      : _uploading
                      ? 'Sending voice note...'
                      : 'Find a doctor',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Where does it hurt?" — folded until opened; shows what's picked.
class _WhereItHurts extends StatelessWidget {
  const _WhereItHurts({
    required this.open,
    required this.picked,
    required this.onOpen,
    required this.onChanged,
    this.female = false,
  });

  final bool open;
  final List<String> picked;

  /// Show a woman's body.
  final bool female;
  final VoidCallback onOpen;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.lavenderGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.personStanding,
                    color: AppColors.lavender,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Where does it hurt?',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          picked.isEmpty
                              ? 'Show me on the body (optional)'
                              : describeAreas(picked),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: picked.isEmpty
                                ? AppColors.inkSoft
                                : AppColors.lavender,
                            fontWeight: picked.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown, size: 18),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: BodyMap(
                      picked: picked,
                      onChanged: onChanged,
                      female: female,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
