import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

class DoctorOnboardingScreen extends ConsumerStatefulWidget {
  const DoctorOnboardingScreen({super.key});

  @override
  ConsumerState<DoctorOnboardingScreen> createState() =>
      _DoctorOnboardingScreenState();
}

class _DoctorOnboardingScreenState
    extends ConsumerState<DoctorOnboardingScreen> {
  final _nameCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _specialties = <String>{};
  XFile? _document;
  bool _saving = false;
  String? _error;

  Future<void> _pickDocument() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _document = file);
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _licenseCtrl.text.trim().isEmpty ||
        _specialties.isEmpty) {
      setState(() => _error = 'Please fill in all fields and pick at least one specialty.');
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
        final path = '$userId/license.$ext';
        await SupabaseService.client.storage
            .from('verification-documents')
            .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
        docs.add(path);
      }
      await ref
          .read(profileRepositoryProvider)
          .updateDoctorRegistration(
            userId: userId,
            name: _nameCtrl.text.trim(),
            specialties: _specialties.toList(),
            licenseNumber: _licenseCtrl.text.trim(),
            verificationDocuments: docs,
          );
      ref.invalidate(currentDoctorProfileProvider);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor registration')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'We need a few details to verify your medical license before '
              'you can start accepting consultations.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _licenseCtrl,
              decoration: const InputDecoration(
                labelText: 'KMPDC license number',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Specialties', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kSpecialties
                  .map(
                    (s) => FilterChip(
                      label: Text(s),
                      selected: _specialties.contains(s),
                      onSelected: (sel) => setState(
                        () => sel ? _specialties.add(s) : _specialties.remove(s),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(
                _document == null ? 'Upload license document' : 'Change document',
              ),
              onPressed: _pickDocument,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
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
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
