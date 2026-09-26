import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/patient_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/geocoding.dart';
import '../../../services/location_service.dart';
import '../../location/location_picker_screen.dart';

/// Profile › Location: where you are (by name, e.g. "Ruiru, Kiambu, Kenya"),
/// plus directions for deliveries. Used to show the nearest chemists.
class PatientLocationScreen extends ConsumerWidget {
  const PatientLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentPatientProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Location')),
      body: profile.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) => p == null
            ? const ErrorView(message: 'Your profile could not be loaded.')
            : _LocationForm(profile: p),
      ),
    );
  }
}

class _LocationForm extends ConsumerStatefulWidget {
  const _LocationForm({required this.profile});

  final PatientProfile profile;

  @override
  ConsumerState<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends ConsumerState<_LocationForm> {
  late Place? _place = widget.profile.hasLocation
      ? Place(
          name: widget.profile.locationName ?? 'Saved location',
          lat: widget.profile.locationLat!,
          lng: widget.profile.locationLng!,
        )
      : null;
  late final _details = TextEditingController(
    text: widget.profile.locationDetails,
  );
  bool _locating = false;
  bool _saving = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickOnMap() async {
    final picked = await context.push<Place>(
      '/account/location',
      extra: _place,
    );
    if (picked != null && mounted) setState(() => _place = picked);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      Place? named;
      try {
        named = await ref.read(geocoderProvider).reverse(loc.lat, loc.lng);
      } catch (_) {}
      if (mounted) {
        setState(
          () => _place =
              named ??
              Place(name: 'My current location', lat: loc.lat, lng: loc.lng),
        );
      }
    } on LocationException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
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
              allergies: p.allergies,
              currentMedications: p.currentMedications,
              chronicConditions: p.chronicConditions,
              bloodGroup: p.bloodGroup,
              heightCm: p.heightCm,
              weightKg: p.weightKg,
              emergencyContactName: p.emergencyContactName,
              emergencyContactPhone: p.emergencyContactPhone,
              locationLat: _place?.lat,
              locationLng: _place?.lng,
              locationName: _place?.name,
              locationDetails: _details.text.trim().isEmpty
                  ? null
                  : _details.text.trim(),
            ),
          );
      ref.invalidate(currentPatientProfileProvider);
      if (mounted) {
        _toast('Location saved');
        context.pop();
      }
    } catch (e) {
      if (mounted) _toast('Could not save: ${friendlyError(e)}');
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
        Text(
          'We use this to show the chemists nearest to you and for deliveries.',
          style: theme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _place == null ? AppColors.white : AppColors.successSoft,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _place == null ? AppColors.border : AppColors.successSoft,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _place == null ? LucideIcons.mapPinOff : LucideIcons.mapPin,
                color: _place == null ? AppColors.inkFaint : AppColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _place?.name ?? 'No location set yet',
                  style: theme.titleSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.locateFixed, size: 18),
                label: const Text('Use my location'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(LucideIcons.map, size: 18),
                label: const Text('Pick on map'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text('Directions (optional)', style: theme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: _details,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'Estate, building, house number or a landmark, e.g. "Blue gate opposite Ruiru Mall"',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save location'),
        ),
      ],
    );
  }
}
