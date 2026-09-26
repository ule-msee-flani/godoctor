import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/chat.dart';

/// The free 24-hour chat after a consultation. Opening/closing the window,
/// who may write, and notifications are all enforced in the database (see
/// the visit_chat_reminders migration).
class ChatRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<ChatThread>> myChats() async {
    final rows = await _client.rpc('my_chats') as List;
    return rows
        .map((r) => ChatThread.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// New messages arrive live.
  Stream<List<ChatMessage>> watchMessages(String consultationId) => _client
      .from('consultation_messages')
      .stream(primaryKey: ['id'])
      .eq('consultation_id', consultationId)
      .order('created_at', ascending: true)
      .map((rows) => rows.map(ChatMessage.fromMap).toList());

  /// Any message in any of my chats (to refresh the Chats list and badge).
  Stream<void> watchAny() => _client
      .from('consultation_messages')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false)
      .limit(1)
      .map((_) {});

  Future<void> send(String consultationId, String body) => _client.rpc(
    'send_chat_message',
    params: {'p_consultation_id': consultationId, 'p_body': body},
  );

  Future<void> markRead(String consultationId) => _client.rpc(
    'mark_chat_read',
    params: {'p_consultation_id': consultationId},
  );
}
