import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/location_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentPatientProfileProvider);
    final authUser = ref.watch(authRepositoryProvider).currentAuthUser;
    final contact = (authUser?.email?.isNotEmpty ?? false)
        ? authUser!.email!
        : (authUser?.phone ?? '');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (p) {
          if (p == null) {
            return const ErrorView(
              message: 'Your profile could not be loaded.',
            );
          }
          return _ProfileForm(profile: p, contact: contact);
        },
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile, required this.contact});

  final PatientProfile profile;
  final String contact;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController(text: widget.profile.name);
  late final _allergies = TextEditingController(text: widget.profile.allergies);
  late final _medications = TextEditingController(
    text: widget.profile.currentMedications,
  );
  late final _conditions = TextEditingController(
    text: widget.profile.chronicConditions,
  );
  late DateTime? _dob = widget.profile.dateOfBirth;
  late double? _lat = widget.profile.locationLat;
  late double? _lng = widget.profile.locationLng;

  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _allergies.dispose();
    _medications.dispose();
    _conditions.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = loc.lat;
        _lng = loc.lng;
      });
    } on LocationException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('Please enter your name.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updatePatientProfile(
            PatientProfile(
              userId: widget.profile.userId,
              name: _name.text.trim(),
              dateOfBirth: _dob,
              locationLat: _lat,
              locationLng: _lng,
              allergies: _clean(_allergies),
              currentMedications: _clean(_medications),
              chronicConditions: _clean(_conditions),
            ),
          );
      ref.invalidate(currentPatientProfileProvider);
      if (mounted) _toast('Profile saved');
    } catch (e) {
      if (mounted) _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = _lat != null && _lng != null;
    final initial = _name.text.trim().isNotEmpty
        ? _name.text.trim()[0].toUpperCase()
        : '?';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                initial,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.profile.name.isEmpty
                        ? 'Your profile'
                        : widget.profile.name,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (widget.contact.isNotEmpty)
                    Text(widget.contact, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionTitle(icon: LucideIcons.user, text: 'About you'),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickDob,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of birth',
              suffixIcon: Icon(LucideIcons.calendar, size: 18),
            ),
            child: Text(
              _dob == null
                  ? 'Not set'
                  : _dob!.toLocal().toString().split(' ').first,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: _dob == null ? AppColors.inkFaint : AppColors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _SectionTitle(icon: LucideIcons.heartPulse, text: 'Health details'),
        const SizedBox(height: 4),
        Text(
          'Shared only with the doctors you consult, to help them treat you safely.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _allergies,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Allergies',
            hintText: 'E.g. penicillin',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _medications,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Current medications'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _conditions,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Chronic conditions',
            hintText: 'E.g. asthma, diabetes',
          ),
        ),
        const SizedBox(height: 22),
        _SectionTitle(icon: LucideIcons.mapPin, text: 'Your location'),
        const SizedBox(height: 4),
        Text(
          'Used to show the chemists closest to you first.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hasLocation ? AppColors.successSoft : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasLocation ? AppColors.successSoft : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasLocation ? LucideIcons.circleCheck : LucideIcons.mapPinOff,
                color: hasLocation ? AppColors.success : AppColors.inkFaint,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasLocation
                      ? 'Location saved (${_lat!.toStringAsFixed(3)}, ${_lng!.toStringAsFixed(3)})'
                      : 'No location set yet',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _locating ? null : _useCurrentLocation,
          icon: _locating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.locate, size: 18),
          label: Text(
            hasLocation ? 'Update my location' : 'Use my current location',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save changes'),
        ),
        const SizedBox(height: 24),
        const InstallPromptBanner(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          icon: const Icon(LucideIcons.logOut, size: 18),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

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
