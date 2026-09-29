import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/patient_card.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

/// What the QR holds: a prefix so scanners know it's ours, and the code.
String cardQrPayload(String code) => 'GODOCTOR:$code';

/// The code in a scanned QR (or a typed code), or null if it isn't ours.
String? codeFromQr(String raw) {
  final t = raw.trim().toUpperCase();
  final m = RegExp(r'^(?:GODOCTOR:)?([A-Z0-9]{8})$').firstMatch(t);
  return m?.group(1);
}

/// "GD-1A2B-3C4D" from a user id.
String godoctorId(String userId) {
  final s = userId.replaceAll('-', '').toUpperCase();
  return 'GD-${s.substring(0, 4)}-${s.substring(4, 8)}';
}

/// My GoDoctor health card: who I am, what matters in an emergency, and a
/// QR a doctor or pharmacist scans to see my card (the code lasts 15
/// minutes; I'm told whenever it's opened).
class HealthCardScreen extends ConsumerStatefulWidget {
  const HealthCardScreen({super.key});

  @override
  ConsumerState<HealthCardScreen> createState() => _HealthCardScreenState();
}

class _HealthCardScreenState extends ConsumerState<HealthCardScreen> {
  ({String code, DateTime expiresAt})? _code;
  String? _error;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _newCode();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final c = _code;
      if (c != null && DateTime.now().isAfter(c.expiresAt)) {
        _newCode();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _newCode() async {
    setState(() {
      _code = null;
      _error = null;
    });
    try {
      final c = await ref.read(profileRepositoryProvider).createShareCode();
      if (mounted) setState(() => _code = c);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = ref.watch(currentPatientProfileProvider).valueOrNull;
    final user = ref.watch(currentAppUserProvider).valueOrNull;
    final allergies = PatientCard.items(p?.allergies);
    final left = _code == null
        ? Duration.zero
        : _code!.expiresAt.difference(DateTime.now());
    final mm = left.inMinutes.clamp(0, 99).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).clamp(0, 59).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('My health card')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x331B63F2),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.heartPulse, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'GoDoctor',
                      style: text.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Health card',
                      style: text.labelMedium?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: UserAvatar(
                        name: p?.name ?? '?',
                        path: user?.avatarUrl,
                        radius: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (p?.name ?? '').isEmpty
                                ? 'GoDoctor patient'
                                : p!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (user != null)
                            Text(
                              godoctorId(user.id),
                              style: text.labelLarge?.copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _Fact(label: 'Blood group', value: p?.bloodGroup ?? '—'),
                    const SizedBox(width: 10),
                    _Fact(
                      label: 'Allergies',
                      value: allergies.isEmpty
                          ? 'None known'
                          : allergies.join(', '),
                      warn: allergies.isNotEmpty,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: _code != null
                      ? QrImageView(
                          data: cardQrPayload(_code!.code),
                          size: 220,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: AppColors.ink,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: AppColors.ink,
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Text(_error!, textAlign: TextAlign.center),
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),
                const SizedBox(height: 12),
                if (_code != null) ...[
                  Text(
                    _code!.code.replaceAllMapped(
                      RegExp(r'^(.{4})(.{4})$'),
                      (m) => '${m[1]} ${m[2]}',
                    ),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  Text(
                    'Valid for $mm:$ss',
                    style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
                TextButton.icon(
                  onPressed: _newCode,
                  icon: const Icon(LucideIcons.refreshCw, size: 16),
                  label: const Text('New code'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                size: 18,
                color: AppColors.success,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Show this to your doctor or pharmacist. Scanning it lets '
                  'them see your allergies, conditions, medicines and latest '
                  'numbers. We\'ll tell you whenever your card is opened.',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.warn = false});

  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (warn) ...[
                  const Icon(
                    LucideIcons.triangleAlert,
                    size: 12,
                    color: Color(0xFFFFC9C6),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: text.labelSmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
