import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import '../patient/health/health_card.dart' show codeFromQr;
import 'patient_card_sheet.dart';

/// For doctors and pharmacies: scan a patient's GoDoctor health card (or
/// type its code) to open their card.
class ScanCardScreen extends ConsumerStatefulWidget {
  const ScanCardScreen({super.key});

  @override
  ConsumerState<ScanCardScreen> createState() => _ScanCardScreenState();
}

class _ScanCardScreenState extends ConsumerState<ScanCardScreen> {
  final _typed = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  Future<void> _open(String raw) async {
    final code = codeFromQr(raw);
    if (code == null) {
      setState(() => _error = 'That isn\'t a GoDoctor health card.');
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    try {
      final card = await ref
          .read(profileRepositoryProvider)
          .patientCardByCode(code);
      if (!mounted) return;
      if (card == null) {
        setState(() => _error = 'We couldn\'t find that card.');
        return;
      }
      final pharmacy =
          ref.read(currentAppUserProvider).valueOrNull?.role ==
          UserRole.chemist;
      final router = GoRouter.of(context);
      await showPatientCard(
        context,
        card.userId,
        forPharmacy: pharmacy,
        preloaded: card,
      );
      if (mounted) router.pop();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan health card')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null && !_busy) _open(raw);
                    },
                    errorBuilder: (context, error) => const ColoredBox(
                      color: AppColors.ink,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'The camera isn\'t available. Type the code below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Aim here.
                  Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                  if (_busy)
                    const ColoredBox(
                      color: Color(0x88000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Point the camera at the QR on the patient\'s GoDoctor health '
            'card. The code is valid for 15 minutes.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 9,
                  decoration: const InputDecoration(
                    hintText: 'Or type the code',
                    counterText: '',
                    prefixIcon: Icon(LucideIcons.keyboard, size: 18),
                  ),
                  onSubmitted: (v) => _open(v.replaceAll(' ', '')),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _open(_typed.text.replaceAll(' ', '')),
                child: const Text('Open'),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
        ],
      ),
    );
  }
}
