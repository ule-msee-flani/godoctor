/// One post-consultation chat, as listed in Chats.
class ChatThread {
  const ChatThread({
    required this.consultationId,
    required this.otherId,
    required this.otherName,
    required this.otherRole,
    required this.specialty,
    required this.symptoms,
    required this.consultedAt,
    required this.isOpen,
    required this.unread,
    this.otherAvatar,
    this.closesAt,
    this.lastBody,
    this.lastAt,
    this.lastFromMe = false,
  });

  final String consultationId;
  final String otherId;
  final String otherName;
  final String? otherAvatar;

  /// patient | doctor
  final String otherRole;
  final String specialty;
  final String symptoms;
  final DateTime consultedAt;
  final DateTime? closesAt;
  final bool isOpen;
  final String? lastBody;
  final DateTime? lastAt;
  final bool lastFromMe;
  final int unread;

  factory ChatThread.fromMap(Map<String, dynamic> m) => ChatThread(
    consultationId: m['consultation_id'] as String,
    otherId: m['other_id'] as String,
    otherName: (m['other_name'] as String?) ?? '',
    otherAvatar: m['other_avatar'] as String?,
    otherRole: (m['other_role'] as String?) ?? 'doctor',
    specialty: (m['specialty'] as String?) ?? '',
    symptoms: (m['symptoms'] as String?) ?? '',
    consultedAt: DateTime.parse(m['consulted_at'] as String).toLocal(),
    closesAt: m['closes_at'] == null
        ? null
        : DateTime.parse(m['closes_at'] as String).toLocal(),
    isOpen: (m['is_open'] as bool?) ?? false,
    lastBody: m['last_body'] as String?,
    lastAt: m['last_at'] == null
        ? null
        : DateTime.parse(m['last_at'] as String).toLocal(),
    lastFromMe: (m['last_from_me'] as bool?) ?? false,
    unread: (m['unread'] as num?)?.toInt() ?? 0,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.consultationId,
    required this.body,
    required this.createdAt,
    this.senderId,
    this.isSystem = false,
  });

  final String id;
  final String consultationId;
  final String? senderId;
  final String body;
  final bool isSystem;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    consultationId: m['consultation_id'] as String,
    senderId: m['sender_id'] as String?,
    body: (m['body'] as String?) ?? '',
    isSystem: m['kind'] == 'system',
    createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
  );
}
