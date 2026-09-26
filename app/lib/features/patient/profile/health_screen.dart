import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

const kBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/// Profile › Health details: what doctors should know before treating you.
class HealthDetailsScreen extends ConsumerWidget {
  const HealthDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentPatientProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Health details')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) => p == null
            ? const ErrorView(message: 'Your profile could not be loaded.')
            : _HealthForm(profile: p),
      ),
    );
  }
}

class _HealthForm extends ConsumerStatefulWidget {
  const _HealthForm({required this.profile});

  final PatientProfile profile;

  @override
  ConsumerState<_HealthForm> createState() => _HealthFormState();
}

class _HealthFormState extends ConsumerState<_HealthForm> {
  late final _allergies = TextEditingController(text: widget.profile.allergies);
  late final _meds = TextEditingController(
    text: widget.profile.currentMedications,
  );
  late final _conditions = TextEditingController(
    text: widget.profile.chronicConditions,
  );
  late final _height = TextEditingController(
    text: widget.profile.heightCm?.toStringAsFixed(0),
  );
  late final _weight = TextEditingController(
    text: widget.profile.weightKg?.toStringAsFixed(0),
  );
  late String? _blood = widget.profile.bloodGroup;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_allergies, _meds, _conditions, _height, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  void _addTo(TextEditingController c, String value) {
    final items = c.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (items.any((s) => s.toLowerCase() == value.toLowerCase())) return;
    c.text = [...items, value].join(', ');
    setState(() {});
  }

  Future<void> _save() async {
    final h = _height.text.trim().isEmpty
        ? null
        : double.tryParse(_height.text.trim());
    final w = _weight.text.trim().isEmpty
        ? null
        : double.tryParse(_weight.text.trim());
    if ((_height.text.trim().isNotEmpty && (h == null || h < 30 || h > 260)) ||
        (_weight.text.trim().isNotEmpty && (w == null || w < 1 || w > 400))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check height (cm) and weight (kg).')),
      );
      return;
    }
    final p = widget.profile;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePatientProfile(
            PatientProfile(
              userId: p.userId,
              name: p.name,
              dateOfBirth: p.dateOfBirth,
              locationLat: p.locationLat,
              locationLng: p.locationLng,
              locationName: p.locationName,
              locationDetails: p.locationDetails,
              emergencyContactName: p.emergencyContactName,
              emergencyContactPhone: p.emergencyContactPhone,
              allergies: _text(_allergies),
              currentMedications: _text(_meds),
              chronicConditions: _text(_conditions),
              bloodGroup: _blood,
              heightCm: h,
              weightKg: w,
            ),
          );
      ref.invalidate(currentPatientProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Health details saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySofter,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only doctors you consult can see this. It helps them treat you safely.',
                  style: theme.bodySmall?.copyWith(color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
        _Block(
          icon: LucideIcons.triangleAlert,
          color: AppColors.danger,
          title: 'Allergies',
          hint: 'Medicines, foods or anything else, and what happens',
          controller: _allergies,
          quick: const [
            'Penicillin',
            'Sulfa drugs',
            'Aspirin',
            'Peanuts',
            'Latex',
          ],
          onQuick: (v) => _addTo(_allergies, v),
        ),
        _Block(
          icon: LucideIcons.pill,
          title: 'Current medications',
          hint: 'Name, dose and how often, e.g. Metformin 500 mg twice daily',
          controller: _meds,
        ),
        _Block(
          icon: LucideIcons.heartPulse,
          title: 'Chronic conditions',
          hint: 'Long-term conditions and past operations',
          controller: _conditions,
          quick: const [
            'Hypertension',
            'Diabetes',
            'Asthma',
            'HIV',
            'Sickle cell',
            'Epilepsy',
          ],
          onQuick: (v) => _addTo(_conditions, v),
        ),
        const SizedBox(height: 22),
        Text('Blood group', style: theme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in kBloodGroups)
              ChoiceChip(
                label: Text(g),
                selected: _blood == g,
                onSelected: (sel) => setState(() => _blood = sel ? g : null),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Height',
                  suffixText: 'cm',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _weight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  suffixText: 'kg',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save health details'),
        ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.icon,
    required this.title,
    required this.hint,
    required this.controller,
    this.color = AppColors.primary,
    this.quick = const [],
    this.onQuick,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String hint;
  final TextEditingController controller;
  final List<String> quick;
  final ValueChanged<String>? onQuick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title, style: theme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: hint),
          ),
          if (quick.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final q in quick)
                  ActionChip(
                    avatar: const Icon(LucideIcons.plus, size: 14),
                    label: Text(q),
                    onPressed: () => onQuick?.call(q),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
