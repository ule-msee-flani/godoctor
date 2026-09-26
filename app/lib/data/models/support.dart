/// support | complaint | feedback | account_deletion
enum SupportKind {
  support('support', 'Help request'),
  complaint('complaint', 'Complaint'),
  feedback('feedback', 'Feedback'),
  accountDeletion('account_deletion', 'Account deletion');

  const SupportKind(this.db, this.label);

  final String db;
  final String label;

  static SupportKind fromDb(String? v) =>
      values.firstWhere((k) => k.db == v, orElse: () => SupportKind.support);
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.kind,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.lastMessageAt,
    this.relatedConsultationId,
    this.relatedOrderId,
  });

  final String id;
  final String userId;
  final SupportKind kind;
  final String subject;

  /// open | answered | closed
  final String status;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final String? relatedConsultationId;
  final String? relatedOrderId;

  bool get isClosed => status == 'closed';

  factory SupportTicket.fromMap(Map<String, dynamic> m) => SupportTicket(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    kind: SupportKind.fromDb(m['kind'] as String?),
    subject: (m['subject'] as String?) ?? '',
    status: (m['status'] as String?) ?? 'open',
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
    lastMessageAt: DateTime.parse(m['last_message_at'] as String).toLocal(),
    relatedConsultationId: m['related_consultation_id'] as String?,
    relatedOrderId: m['related_order_id'] as String?,
  );
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.fromStaff,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String ticketId;
  final String senderId;
  final bool fromStaff;
  final String body;
  final DateTime createdAt;

  factory SupportMessage.fromMap(Map<String, dynamic> m) => SupportMessage(
    id: m['id'] as String,
    ticketId: m['ticket_id'] as String,
    senderId: m['sender_id'] as String,
    fromStaff: (m['from_staff'] as bool?) ?? false,
    body: (m['body'] as String?) ?? '',
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}

class AppRating {
  const AppRating({required this.stars, this.comment});

  final int stars;
  final String? comment;

  factory AppRating.fromMap(Map<String, dynamic> m) => AppRating(
    stars: (m['stars'] as num).toInt(),
    comment: m['comment'] as String?,
  );
}
