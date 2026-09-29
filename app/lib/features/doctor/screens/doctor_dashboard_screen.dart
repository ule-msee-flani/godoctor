import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/greeting_header.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../widgets/active_patient_section.dart';
import '../widgets/doctor_appointments_section.dart';
import '../widgets/today_card.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../core/widgets/motion.dart';
import '../../../services/live_updates.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentDoctorProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: friendlyError(e)),
          data: (profile) {
            if (profile == null || userId == null) {
              return const ErrorView(message: 'Profile not found');
            }
            return _DashboardBody(profile: profile, doctorId: userId);
          },
        ),
      ),
    );
  }
}

/// "Dr Jane" from however the name was saved.
String _doctorName(String name) {
  final clean = name
      .replaceFirst(RegExp(r'^(dr\.?|doctor)\s+', caseSensitive: false), '')
      .trim();
  final first = clean
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .firstOrNull;
  return first == null ? 'Doctor' : 'Dr $first';
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile, required this.doctorId});

  final DoctorProfile profile;
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LiveRefresh(
      onRefresh: () async {
        ref.invalidate(doctorTodayProvider);
        ref.invalidate(currentDoctorProfileProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FadeSlideIn(
            child: GreetingHeader(
              name: _doctorName(profile.name),
              subtitle: switch (profile.status) {
                DoctorStatus.busy => 'You\'re with a patient right now.',
                DoctorStatus.available =>
                  'You\'re online. Patients can choose you now.',
                _ =>
                  'You\'re offline. Go online when you\'re ready to see patients.',
              },
              avatarPath: ref
                  .watch(currentAppUserProvider)
                  .valueOrNull
                  ?.avatarUrl,
              onAvatarTap: () => context.go('/doctor/profile'),
              actions: [
                IconButton(
                  tooltip: 'Scan a health card',
                  icon: const Icon(LucideIcons.scanQrCode),
                  onPressed: () => context.push('/account/scan-card'),
                ),
                NotificationBell(
                  count: ref.watch(unreadNotificationCountProvider),
                  onPressed: () => context.push('/doctor/notifications'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FadeSlideIn(
            index: 1,
            child: _AvailabilityCard(status: profile.status),
          ),
          const SizedBox(height: 12),
          const FadeSlideIn(index: 2, child: DoctorTodayCard()),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 3,
            child: ActivePatientSection(doctorId: doctorId),
          ),
          const SizedBox(height: 20),
          const FadeSlideIn(index: 4, child: DoctorAppointmentsSection()),
        ],
      ),
    );
  }
}

/// "Available for consultations" on/off. Flips at once and reverts (with
/// the reason) if the server says no.
class _AvailabilityCard extends ConsumerStatefulWidget {
  const _AvailabilityCard({required this.status});

  final DoctorStatus status;

  @override
  ConsumerState<_AvailabilityCard> createState() => _AvailabilityCardState();
}

class _AvailabilityCardState extends ConsumerState<_AvailabilityCard> {
  bool? _pending;

  Future<void> _set(bool on) async {
    setState(() => _pending = on);
    try {
      await ref.read(profileRepositoryProvider).setDoctorAvailability(on);
      ref.invalidate(currentDoctorProfileProvider);
      await ref.read(currentDoctorProfileProvider.future);
    } catch (e) {
      if (mounted) {
        final msg = friendlyError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.contains('not yet verified')
                  ? 'Your licence has not been verified yet, so you can\'t go online.'
                  : 'Could not change your status: $msg',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.status == DoctorStatus.busy;
    final on = _pending ?? widget.status == DoctorStatus.available;
    final theme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            if (on && !busy)
              const PulseDot(color: AppColors.success, size: 12)
            else
              SizedBox(
                width: 26,
                height: 26,
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: busy ? AppColors.warning : AppColors.inkFaint,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    busy
                        ? 'In a consultation'
                        : on
                        ? 'Available for consultations'
                        : 'Offline',
                    style: theme.titleMedium,
                  ),
                  Text(
                    busy
                        ? 'You\'ll be available again when it ends.'
                        : on
                        ? 'Patients can choose you now.'
                        : 'Switch on to receive patients.',
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(
              value: on,
              onChanged: busy || _pending != null ? null : _set,
            ),
          ],
        ),
      ),
    );
  }
}
