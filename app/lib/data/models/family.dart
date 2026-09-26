/// Someone linked to me as family (either I invited them or they invited me).
class FamilyMember {
  const FamilyMember({
    required this.linkId,
    required this.userId,
    required this.name,
    required this.relationship,
    required this.status,
    required this.invitedByMe,
    required this.online,
    this.avatarUrl,
  });

  final String linkId;
  final String userId;
  final String name;
  final String? avatarUrl;

  /// Label chosen by whoever sent the invitation (e.g. "Mother").
  final String relationship;

  /// pending | accepted | declined
  final String status;
  final bool invitedByMe;

  /// Had the app open in the last couple of minutes.
  final bool online;

  bool get isAccepted => status == 'accepted';

  /// An invitation someone sent me that I haven't answered.
  bool get awaitsMyAnswer => status == 'pending' && !invitedByMe;

  factory FamilyMember.fromMap(Map<String, dynamic> m) => FamilyMember(
    linkId: m['link_id'] as String,
    userId: m['user_id'] as String,
    name: (m['name'] as String?) ?? 'GoDoctor user',
    avatarUrl: m['avatar_url'] as String?,
    relationship: (m['relationship'] as String?) ?? 'Family',
    status: (m['status'] as String?) ?? 'pending',
    invitedByMe: (m['invited_by_me'] as bool?) ?? false,
    online: (m['online'] as bool?) ?? false,
  );
}

/// Someone in a consultation: the patient, the doctor or a family listener.
class SessionPerson {
  const SessionPerson({
    required this.userId,
    required this.name,
    required this.role,
    required this.status,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String? avatarUrl;

  /// patient | doctor | family
  final String role;

  /// invited | joined | left | declined (always joined for patient/doctor)
  final String status;

  bool get isFamily => role == 'family';
  bool get isJoined => status == 'joined';

  factory SessionPerson.fromMap(Map<String, dynamic> m) => SessionPerson(
    userId: m['user_id'] as String,
    name: (m['name'] as String?) ?? '',
    avatarUrl: m['avatar_url'] as String?,
    role: (m['role'] as String?) ?? 'family',
    status: (m['status'] as String?) ?? 'invited',
  );
}

/// What an invited family member may see about a consultation.
class FamilySessionInfo {
  const FamilySessionInfo({
    required this.consultationId,
    required this.patientName,
    required this.specialty,
    required this.status,
    required this.myStatus,
    this.doctorName,
    this.startedAt,
  });

  final String consultationId;
  final String patientName;
  final String? doctorName;
  final String specialty;

  /// Consultation status as stored (e.g. in_progress, completed).
  final String status;
  final DateTime? startedAt;

  /// My participant status: invited | joined | left | declined
  final String myStatus;

  bool get isLive => status == 'in_progress';
  bool get isOver =>
      const {'completed', 'cancelled', 'expired'}.contains(status);

  factory FamilySessionInfo.fromMap(Map<String, dynamic> m) =>
      FamilySessionInfo(
        consultationId: m['consultation_id'] as String,
        patientName: (m['patient_name'] as String?) ?? '',
        doctorName: m['doctor_name'] as String?,
        specialty: (m['specialty'] as String?) ?? '',
        status: (m['status'] as String?) ?? '',
        startedAt: m['started_at'] == null
            ? null
            : DateTime.tryParse(m['started_at'] as String)?.toLocal(),
        myStatus: (m['my_status'] as String?) ?? 'invited',
      );
}
