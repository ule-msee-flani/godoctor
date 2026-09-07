import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/emergency_check.dart';

class IntakeFormScreen extends ConsumerStatefulWidget {
  const IntakeFormScreen({super.key});

  @override
  ConsumerState<IntakeFormScreen> createState() => _IntakeFormScreenState();
}

class _IntakeFormScreenState extends ConsumerState<IntakeFormScreen> {
  String _specialty = kSpecialties.first;
  final _symptomsCtrl = TextEditingController();
  String? _duration;
  String _severity = 'Moderate';
  bool _submitting = false;
  EmergencyCheckResult? _emergencyResult;

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
      return _EmergencyStopView(matchedKeyword: _emergencyResult!.matchedKeyword);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tell us what\'s going on')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Specialty', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _specialty,
                items: kSpecialties
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _specialty = v ?? _specialty),
              ),
              const SizedBox(height: 20),
              Text('Describe your symptoms', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _symptomsCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'E.g. fever and headache since yesterday...',
                ),
              ),
              const SizedBox(height: 20),
              Text('How long has this been going on?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
              const SizedBox(height: 20),
              Text('Severity', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
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
              FilledButton(
                onPressed:
                    _submitting || _symptomsCtrl.text.trim().isEmpty
                    ? null
                    : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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

/// Hard stop shown when the emergency keyword check trips. Always gives a
/// path to reach a human -- never a dead end (per spec).
class _EmergencyStopView extends StatelessWidget {
  const _EmergencyStopView({this.matchedKeyword});

  final String? matchedKeyword;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emergency_outlined, color: Colors.red.shade700, size: 64),
              const SizedBox(height: 20),
              Text(
                'This sounds like a medical emergency',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'GoDoctor cannot safely handle this over a delayed video consultation. '
                'Please contact emergency services or go to the nearest hospital right away.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                onPressed: () => launchDialer('999'),
                icon: const Icon(Icons.call),
                label: const Text('Call 999 (Emergency Services)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the device dialer via a `tel:` link. On desktop web where no
/// dialer app is registered this silently no-ops (browser handles it), but
/// the number is also shown on-screen so it's never a dead end.
Future<void> launchDialer(String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  try {
    await launchUrl(uri);
  } catch (_) {
    // No dialer available (e.g. plain desktop browser) -- the number is
    // already visible in the button label for the user to dial manually.
  }
}
