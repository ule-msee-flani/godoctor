import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

/// Inbox for booking confirmations, reminders and cancellations. Shared by
/// patients and doctors -- [appointmentRoute] says where tapping an
/// appointment notification should go for the current role.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({
    super.key,
    this.appointmentRoute = '/patient/appointment',
  });

  /// Null = tapping only marks the notification read.
  final String? appointmentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final hasUnread = ref.watch(unreadNotificationCountProvider) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread && userId != null)
            TextButton(
              onPressed: () =>
                  ref.read(notificationRepositoryProvider).markAllRead(userId),
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: async.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyView(
              message:
                  'You\'re all caught up.\nBooking confirmations and reminders will show up here.',
              icon: LucideIcons.bellOff,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _NotificationTile(
              item: items[i],
              onTap: () async {
                final n = items[i];
                if (!n.isRead) {
                  await ref.read(notificationRepositoryProvider).markRead(n.id);
                }
                if (!context.mounted) return;
                final route = _routeFor(n, isPatient: appointmentRoute != null);
                if (route != null) {
                  context.push(route);
                  return;
                }
                // Prescriptions open straight on "order your medicines"
                // (patients only; doctors pass a null appointmentRoute).
                if (n.kind == 'prescription_issued' &&
                    n.prescriptionId != null &&
                    appointmentRoute != null) {
                  context.push(
                    '/patient/prescription/${n.prescriptionId}/order',
                  );
                  return;
                }
                if (appointmentRoute != null && n.consultationId != null) {
                  context.push('$appointmentRoute/${n.consultationId}');
                }
              },
            ),
          );
        },
      ),
    );
  }
}

/// Where tapping a notification of the newer kinds should go.
String? _routeFor(AppNotificationItem n, {required bool isPatient}) {
  final ticket = n.data['ticket_id'] as String?;
  return switch (n.kind) {
    'support_reply' when ticket != null => '/account/support/$ticket',
    'family_invite' ||
    'family_accepted' when isPatient => '/patient/profile/family',
    'family_session_invite' when isPatient && n.consultationId != null =>
      '/patient/family-session/${n.consultationId}',
    'family_joined' when isPatient && n.consultationId != null =>
      '/patient/call/${n.consultationId}',
    _ => null,
  };
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotificationItem item;
  final VoidCallback onTap;

  IconData get _icon => switch (item.kind) {
    'appointment_booked' => LucideIcons.calendarCheck,
    'appointment_reminder' => LucideIcons.bellRing,
    'appointment_cancelled' => LucideIcons.calendarX,
    'appointment_rescheduled' => LucideIcons.calendarClock,
    'prescription_issued' => LucideIcons.fileCheck,
    'family_invite' || 'family_accepted' => LucideIcons.users,
    'family_session_invite' || 'family_joined' => LucideIcons.headphones,
    'support_reply' => LucideIcons.headset,
    'announcement' => LucideIcons.megaphone,
    'patient_selected' => LucideIcons.userRound,
    'patient_paid' => LucideIcons.circleCheck,
    _ => LucideIcons.bell,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      color: item.isRead ? AppColors.white : AppColors.primarySoft,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(_icon, size: 20, color: AppColors.ink),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: theme.titleSmall),
                    if ((item.body ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.body!, style: theme.bodyMedium),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formatDateTime(item.createdAt),
                      style: theme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
