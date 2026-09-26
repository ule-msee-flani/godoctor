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
import '../../../services/notification_routes.dart';

/// The notification inbox, shared by patients, doctors, chemists and
/// admins. Tapping an item opens the screen it is about (same map as push
/// notifications: see notification_routes.dart).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final hasUnread = ref.watch(unreadNotificationCountProvider) > 0;
    final role = ref.watch(currentAppUserProvider).valueOrNull?.role;

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
          IconButton(
            tooltip: 'Notification settings',
            icon: const Icon(LucideIcons.settings2),
            onPressed: () => context.push('/account/notifications'),
          ),
          const SizedBox(width: 4),
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
                final route = routeForNotification(
                  kind: n.kind,
                  data: n.data,
                  role: role,
                );
                if (route != null) context.push(route);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotificationItem item;
  final VoidCallback onTap;

  IconData get _icon => switch (item.kind) {
    'patient_selected' || 'patient_waiting' => LucideIcons.userRound,
    'patient_paid' || 'payment_receipt' => LucideIcons.receipt,
    'doctor_ready' => LucideIcons.video,
    'payment_window_ending' => LucideIcons.timer,
    'appointment_booked' => LucideIcons.calendarCheck,
    'appointment_reminder' => LucideIcons.bellRing,
    'appointment_cancelled' ||
    'consultation_cancelled' ||
    'request_expired' ||
    'patient_cancelled' => LucideIcons.calendarX,
    'appointment_rescheduled' => LucideIcons.calendarClock,
    'consultation_completed' || 'review_new' => LucideIcons.star,
    'prescription_issued' => LucideIcons.fileCheck,
    'order_new' => LucideIcons.shoppingBag,
    'order_confirmed' || 'order_ready' || 'order_completed' =>
      LucideIcons.packageCheck,
    'order_disputed' || 'order_refunded' => LucideIcons.packageX,
    'family_invite' || 'family_accepted' => LucideIcons.users,
    'family_session_invite' || 'family_joined' => LucideIcons.headphones,
    'support_reply' || 'support_new' || 'support_user_reply' =>
      LucideIcons.headset,
    'verification_approved' ||
    'verification_removed' ||
    'verification_submitted' => LucideIcons.shieldCheck,
    'emergency_flagged' => LucideIcons.siren,
    'announcement' => LucideIcons.megaphone,
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
