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

  // --- Push notifications ---

  /// Links this phone/browser to the signed-in user so pushes reach it.
  Future<void> registerDevice(String token, String platform) => _client.rpc(
    'register_device',
    params: {'p_token': token, 'p_platform': platform},
  );

  /// Called on sign-out so the next person on this device doesn't get
  /// the previous user's notifications.
  Future<void> unregisterDevice(String token) =>
      _client.rpc('unregister_device', params: {'p_token': token});

  /// Push categories this user turned off (see the push Edge Function).
  Future<Set<String>> mutedCategories() async {
    final row = await _client
        .from('user_settings')
        .select('push_off')
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return {...((row?['push_off'] as List?) ?? const []).cast<String>()};
  }

  Future<void> setMutedCategories(Set<String> categories) =>
      _client.from('user_settings').upsert({
        'user_id': _client.auth.currentUser!.id,
        'push_off': categories.toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  /// Sends the signed-in user a test notification (inbox + push).
  Future<void> sendTest() => _client.rpc('send_test_notification');
}
