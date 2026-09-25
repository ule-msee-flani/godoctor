import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/emergency_check.dart';
import '../widgets/emergency_stop_view.dart';
import '../widgets/specialty_tiles.dart';

class IntakeFormScreen extends ConsumerStatefulWidget {
  const IntakeFormScreen({
    super.key,
    this.initialSpecialty,
    this.initialSymptoms,
  });

  /// Pre-selected from the home search / specialty tiles.
  final String? initialSpecialty;
  final String? initialSymptoms;

  @override
  ConsumerState<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends ConsumerState<IntakeFormScreen> {
  String _specialty = kSpecialties.first;
  late final _symptomsCtrl = TextEditingController(
    text: widget.initialSymptoms,
  );
  String? _duration;
  String _severity = 'Moderate';
  bool _submitting = false;
  EmergencyCheckResult? _emergencyResult;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSpecialty;
    if (initial != null && kSpecialties.contains(initial)) _specialty = initial;
  }

  @override
  void dispose() {
    _symptomsCtrl.dispose();
    super.dispose();
  }

  static const _durations = ['< 1 hour', 'Today', 'Few days', '> 1 week'];
  static const _severities = ['Mild', 'Moderate', 'Severe'];

  Future<void> _submit() async {
    final emergency = checkForEmergency([_symptomsCtrl.text]);

    if (emergency.flagged) {
      setState(() => _emergencyResult = emergency);
      // Still log the audit trail even though we hard-stop from matching.
      await ref
          .read(consultationRepositoryProvider)
          .requestConsultation(
            specialty: _specialty,
            symptomSummary: _symptomsCtrl.text.trim(),
            symptoms: _symptomsCtrl.text.trim(),
            duration: _duration,
            severity: _severity,
            flaggedEmergency: true,
          );
      return;
    }

    setState(() => _submitting = true);
    try {
      final id = await ref
          .read(consultationRepositoryProvider)
          .requestConsultation(
            specialty: _specialty,
            symptomSummary: _symptomsCtrl.text.trim(),
            symptoms: _symptomsCtrl.text.trim(),
            duration: _duration,
            severity: _severity,
            flaggedEmergency: false,
          );
      if (mounted) context.pushReplacement('/patient/waiting/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emergencyResult != null) {
      return EmergencyStopView(
        matchedKeyword: _emergencyResult!.matchedKeyword,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us what\'s going on')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(icon: LucideIcons.stethoscope, text: 'Specialty'),
              const SizedBox(height: 8),
              SpecialtyGrid(
                selected: _specialty,
                onSelected: (v) => setState(() => _specialty = v),
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                icon: LucideIcons.notebookPen,
                text: 'Describe your symptoms',
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _symptomsCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'E.g. fever and headache since yesterday...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                icon: LucideIcons.clock,
                text: 'How long has this been going on?',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durations
                    .map(
                      (d) => ChoiceChip(
                        label: Text(d),
                        selected: _duration == d,
                        onSelected: (_) => setState(() => _duration = d),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 22),
              _SectionLabel(icon: LucideIcons.gauge, text: 'Severity'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _severities
                    .map(
                      (s) => ChoiceChip(
                        label: Text(s),
                        selected: _severity == s,
                        onSelected: (_) => setState(() => _severity = s),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                icon: const Icon(LucideIcons.search, size: 18),
                onPressed: _submitting || _symptomsCtrl.text.trim().isEmpty
                    ? null
                    : _submit,
                label: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Find me a doctor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
