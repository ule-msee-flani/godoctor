import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/public_doctor.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// Live list of the signed-in user's notifications (newest first).
final notificationsProvider = StreamProvider<List<AppNotificationItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();
  return ref.watch(notificationRepositoryProvider).watch(userId);
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final items = ref.watch(notificationsProvider).valueOrNull;
  return items?.where((n) => !n.isRead).length ?? 0;
});
