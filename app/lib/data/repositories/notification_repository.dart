import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/public_doctor.dart';

/// In-app notifications (booking confirmations, reminders, cancellations).
/// The server writes rows; this reads them live and marks them read.
class NotificationRepository {
  SupabaseClient get _client => SupabaseService.client;

  Stream<List<AppNotificationItem>> watch(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50)
        .map(
          (rows) => rows.map((r) => AppNotificationItem.fromMap(r)).toList(),
        );
  }

  Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  Future<void> markAllRead(String userId) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', userId)
      .isFilter('read_at', null);
}
