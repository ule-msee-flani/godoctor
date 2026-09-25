import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_client.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

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
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  XFile? _document;
  bool _saving = false;
  String? _error;

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
            locationLat: double.tryParse(_latCtrl.text),
            locationLng: double.tryParse(_lngCtrl.text),
            verificationDocuments: docs,
          );
      ref.invalidate(currentChemistProfileProvider);
    } catch (e) {
      setState(() => _error = '$e');
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: Text(
                _document == null
                    ? 'Upload registration document'
                    : 'Change document',
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
