import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/geocoding.dart';
import '../../onboarding/registration_declaration.dart';

class ChemistOnboardingScreen extends ConsumerStatefulWidget {
  const ChemistOnboardingScreen({super.key});

  @override
  ConsumerState<ChemistOnboardingScreen> createState() =>
      _ChemistOnboardingScreenState();
}

class _ChemistOnboardingScreenState
    extends ConsumerState<ChemistOnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _regCtrl = TextEditingController();
  Place? _place;
  XFile? _document;
  bool _saving = false;
  bool _declared = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // What they told us on the welcome path.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = await ref.read(currentChemistProfileProvider.future);
      if (!mounted || c == null) return;
      setState(() {
        if (_nameCtrl.text.isEmpty) _nameCtrl.text = c.businessName;
        if (_regCtrl.text.isEmpty) _regCtrl.text = c.registrationNumber ?? '';
        if (_place == null && c.locationLat != null && c.locationLng != null) {
          _place = Place(
            name: c.locationName ?? 'Pharmacy location',
            lat: c.locationLat!,
            lng: c.locationLng!,
          );
        }
      });
    });
  }

  Future<void> _pickLocation() async {
    final picked = await context.push<Place>(
      '/account/location',
      extra: _place,
    );
    if (picked != null) setState(() => _place = picked);
  }

  Future<void> _pickDocument() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _document = file);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _regCtrl.text.trim().isEmpty) {
      setState(
        () => _error =
            'Please fill in your business name and registration number.',
      );
      return;
    }
    if (!_declared) {
      setState(() => _error = 'Please confirm your details are genuine.');
      return;
    }
    if (!await confirmSubmission(
      context,
      checking: 'your registration with the Pharmacy and Poisons Board',
    )) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = SupabaseService.client.auth.currentUser!.id;
      final docs = <String>[];
      if (_document != null) {
        final bytes = await _document!.readAsBytes();
        final ext = _document!.name.split('.').last;
        final path = '$userId/registration.$ext';
        await SupabaseService.client.storage
            .from('verification-documents')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        docs.add(path);
      }
      await ref
          .read(profileRepositoryProvider)
          .updateChemistRegistration(
            userId: userId,
            businessName: _nameCtrl.text.trim(),
            registrationNumber: _regCtrl.text.trim(),
            locationLat: _place?.lat,
            locationLng: _place?.lng,
            locationName: _place?.name,
            verificationDocuments: docs,
          );
      await ref.read(profileRepositoryProvider).attestRegistration();
      ref.invalidate(currentChemistProfileProvider);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chemist registration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'We need a few details to verify your pharmacy registration '
              'before you can list inventory publicly.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _regCtrl,
              decoration: const InputDecoration(
                labelText: 'Registration number',
              ),
            ),
            const SizedBox(height: 12),
            // Where the pharmacy is: patients see the nearest chemists first.
            Material(
              color: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: ListTile(
                onTap: _pickLocation,
                leading: const Icon(LucideIcons.mapPin, color: AppColors.ink),
                title: Text(
                  _place == null ? 'Pharmacy location' : _place!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  _place == null
                      ? 'Pick it on the map so nearby patients find you'
                      : 'Tap to change',
                ),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.upload, size: 18),
              label: Text(
                _document == null
                    ? 'Upload registration document'
                    : 'Change document',
              ),
              onPressed: _pickDocument,
            ),
            const SizedBox(height: 20),
            DeclarationTile(
              value: _declared,
              regulator: 'the Pharmacy and Poisons Board',
              onChanged: (v) => setState(() {
                _declared = v;
                _error = null;
              }),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving || !_declared ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit for verification'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
