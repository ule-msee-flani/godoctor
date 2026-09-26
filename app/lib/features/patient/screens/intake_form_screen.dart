import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/emergency_check.dart';
import '../consult/consult_flow.dart';
import '../widgets/emergency_stop_view.dart';
import '../widgets/specialty_tiles.dart';

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
  late final _symptomsCtrl = TextEditingController(
    text: widget.initialSymptoms,
  );
  EmergencyCheckResult? _emergencyResult;

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
      _specialty != null && _symptomsCtrl.text.trim().length >= 3;

  Future<void> _findDoctor() async {
    final symptoms = _symptomsCtrl.text.trim();
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

    ref.read(consultDraftProvider.notifier).state = ConsultDraft(
      specialty: _specialty!,
      symptoms: symptoms,
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
                      onSelected: (v) => setState(() => _specialty = v),
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
                onPressed: _canContinue ? _findDoctor : null,
                label: Text(
                  _specialty == null
                      ? 'Choose a category first'
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
