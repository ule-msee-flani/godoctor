import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/providers/repository_providers.dart';

class UploadPrescriptionScreen extends ConsumerStatefulWidget {
  const UploadPrescriptionScreen({super.key});

  @override
  ConsumerState<UploadPrescriptionScreen> createState() =>
      _UploadPrescriptionScreenState();
}

class _UploadPrescriptionScreenState
    extends ConsumerState<UploadPrescriptionScreen> {
  XFile? _picked;
  bool _uploading = false;
  String? _error;

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file != null) setState(() => _picked = file);
  }

  Future<void> _upload() async {
    if (_picked == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final bytes = await _picked!.readAsBytes();
      final ext = _picked!.name.split('.').last;
      await ref
          .read(prescriptionRepositoryProvider)
          .uploadExternalPrescription(fileBytes: bytes, fileExt: ext);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload a prescription')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Take a clear photo of your prescription. The chemist '
                'fulfilling your order will verify it manually before '
                'preparing prescription-only items.',
              ),
              const SizedBox(height: 20),
              if (_picked != null)
                Text('Selected: ${_picked!.name}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(_picked == null ? 'Choose photo' : 'Choose a different photo'),
                onPressed: _pick,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _picked == null || _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Upload'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
