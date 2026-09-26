import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../widgets/active_patient_section.dart';
import '../widgets/doctor_appointments_section.dart';
import '../../../data/providers/repository_providers.dart';

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentDoctorProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor dashboard'),
        actions: [
          Badge(
            isLabelVisible: ref.watch(unreadNotificationCountProvider) > 0,
            label: Text('${ref.watch(unreadNotificationCountProvider)}'),
            offset: const Offset(-4, 4),
            child: IconButton(
              icon: const Icon(LucideIcons.bell),
              tooltip: 'Notifications',
              onPressed: () => context.push('/doctor/notifications'),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: '$e'),
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

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile, required this.doctorId});

  final DoctorProfile profile;
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = profile.status == DoctorStatus.available;
    final isBusy = profile.status == DoctorStatus.busy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isAvailable ? Icons.wifi : Icons.wifi_off,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBusy
                        ? 'In a consultation'
                        : (isAvailable
                              ? 'Available for consultations'
                              : 'Offline'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: isAvailable,
                  onChanged: isBusy
                      ? null
                      : (value) async {
                          await ref
                              .read(profileRepositoryProvider)
                              .setDoctorAvailability(value);
                          ref.invalidate(currentDoctorProfileProvider);
                        },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: profile.specialties
              .map((s) => Chip(label: Text(s)))
              .toList(),
        ),
        const SizedBox(height: 20),
        ActivePatientSection(doctorId: doctorId),
        const SizedBox(height: 20),
        const DoctorAppointmentsSection(),
      ],
    );
  }
}
