import 'enums.dart';

/// One doctor visit as the patient sees it in their history (the
/// `patient_visits()` function): who they saw, when, and what came of it.
class Visit {
  const Visit({
    required this.consultationId,
    this.doctorId,
    this.doctorName,
    this.doctorAvatar,
    required this.specialty,
    required this.symptoms,
    required this.status,
    required this.mode,
    required this.at,
    this.prescriptions = 0,
    this.hasSummary = false,
    this.chatClosesAt,
    this.myRating,
  });

  final String consultationId;
  final String? doctorId;
  final String? doctorName;

  /// Path in the `avatars` bucket.
  final String? doctorAvatar;
  final String specialty;
  final String symptoms;
  final ConsultationStatus status;
  final ConsultationMode mode;
  final DateTime at;
  final int prescriptions;
  final bool hasSummary;
  final DateTime? chatClosesAt;
  final int? myRating;

  bool get isCompleted => status == ConsultationStatus.completed;

  bool get isUpcoming => status == ConsultationStatus.scheduled;

  /// Still under way: waiting for a doctor, paying, or on the call.
  bool get isOngoing =>
      !isCompleted &&
      !isUpcoming &&
      status != ConsultationStatus.cancelled &&
      status != ConsultationStatus.unmatched;

  bool chatOpen(DateTime now) =>
      chatClosesAt != null && chatClosesAt!.isAfter(now);

  String get doctorLabel {
    final name = (doctorName ?? '').trim();
    if (name.isEmpty) return '$specialty doctor';
    return name.toLowerCase().startsWith('dr') ? name : 'Dr. $name';
  }

  /// Where tapping the visit goes.
  String get route => switch (status) {
    ConsultationStatus.completed => '/patient/visit/$consultationId',
    ConsultationStatus.scheduled => '/patient/appointment/$consultationId',
    ConsultationStatus.awaitingPayment =>
      '/patient/consult/$consultationId/pay',
    ConsultationStatus.inProgress => '/patient/call/$consultationId',
    _ => '/patient/waiting/$consultationId',
  };

  factory Visit.fromMap(Map<String, dynamic> m) => Visit(
    consultationId: m['consultation_id'] as String,
    doctorId: m['doctor_id'] as String?,
    doctorName: m['doctor_name'] as String?,
    doctorAvatar: m['doctor_avatar'] as String?,
    specialty: (m['specialty'] as String?) ?? 'General Practice',
    symptoms: (m['symptoms'] as String?) ?? '',
    status: enumFromDb(
      ConsultationStatus.values,
      m['status'] as String?,
      ConsultationStatus.completed,
    ),
    mode: enumFromDb(
      ConsultationMode.values,
      m['mode'] as String?,
      ConsultationMode.onDemand,
    ),
    at: DateTime.parse(m['happened_at'] as String).toLocal(),
    prescriptions: (m['prescriptions'] as num?)?.toInt() ?? 0,
    hasSummary: m['has_summary'] as bool? ?? false,
    chatClosesAt: m['chat_closes_at'] == null
        ? null
        : DateTime.parse(m['chat_closes_at'] as String).toLocal(),
    myRating: (m['my_rating'] as num?)?.toInt(),
  );
}
