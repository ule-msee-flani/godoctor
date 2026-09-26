import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/support.dart';

/// Help requests, complaints and feedback (each a ticket with a message
/// thread), plus the app rating. Admins answer tickets from the admin panel.
class SupportRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<SupportTicket>> myTickets() async {
    final rows = await _client
        .from('support_tickets')
        .select()
        .eq('user_id', _client.auth.currentUser!.id)
        .order('last_message_at', ascending: false);
    return rows.map(SupportTicket.fromMap).toList();
  }

  Future<SupportTicket?> ticket(String id) async {
    final row = await _client
        .from('support_tickets')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : SupportTicket.fromMap(row);
  }

  /// Opens a ticket with its first message; returns the ticket id.
  Future<String> create({
    required SupportKind kind,
    required String subject,
    required String message,
    String? consultationId,
    String? orderId,
  }) async {
    final row = await _client
        .from('support_tickets')
        .insert({
          'kind': kind.db,
          'subject': subject,
          'related_consultation_id': consultationId,
          'related_order_id': orderId,
        })
        .select()
        .single();
    final id = row['id'] as String;
    await send(id, message);
    return id;
  }

  Stream<List<SupportMessage>> watchMessages(String ticketId) => _client
      .from('support_messages')
      .stream(primaryKey: ['id'])
      .eq('ticket_id', ticketId)
      .order('created_at')
      .map((rows) => rows.map(SupportMessage.fromMap).toList());

  Future<void> send(String ticketId, String body, {bool asStaff = false}) =>
      _client.from('support_messages').insert({
        'ticket_id': ticketId,
        'body': body,
        'from_staff': asStaff,
      });

  Future<void> close(String ticketId) => _client
      .from('support_tickets')
      .update({'status': 'closed'})
      .eq('id', ticketId);

  Future<AppRating?> myRating() async {
    final row = await _client
        .from('app_ratings')
        .select()
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row == null ? null : AppRating.fromMap(row);
  }

  Future<void> rate(int stars, String? comment) =>
      _client.from('app_ratings').upsert({
        'user_id': _client.auth.currentUser!.id,
        'stars': stars,
        'comment': comment,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  // --- Admin ---

  Future<List<SupportTicket>> allTickets() async {
    final rows = await _client
        .from('support_tickets')
        .select()
        .order('last_message_at', ascending: false)
        .limit(200);
    return rows.map(SupportTicket.fromMap).toList();
  }

  /// Average stars and how many people rated.
  Future<({double average, int count})> ratingSummary() async {
    final rows = await _client.from('app_ratings').select('stars');
    if (rows.isEmpty) return (average: 0.0, count: 0);
    final total = rows.fold<int>(0, (s, r) => s + (r['stars'] as num).toInt());
    return (average: total / rows.length, count: rows.length);
  }
}
