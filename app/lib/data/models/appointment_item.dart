import 'enums.dart';

/// One appointment or visit in the patient's list (`patient_appointments()`),
/// with the doctor's name, photo and hospital.
class AppointmentItem {
  const AppointmentItem({
    required this.id,
    this.doctorId,
    this.doctorName,
    this.doctorAvatar,
    required this.specialty,
    this.symptoms = '',
    required this.status,
    required this.mode,
    required this.startsAt,
    this.endsAt,
    this.fee,
    this.facility,
    this.myRating,
  });

  final String id;
  final String? doctorId;
  final String? doctorName;

  /// Path in the `avatars` bucket.
  final String? doctorAvatar;
  final String specialty;
  final String symptoms;
  final ConsultationStatus status;
  final ConsultationMode mode;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? fee;

  /// The doctor's hospital or clinic, when they gave one.
  final String? facility;
  final int? myRating;

  bool get isCancelled =>
      status == ConsultationStatus.cancelled ||
      status == ConsultationStatus.unmatched;

  bool get isCompleted => status == ConsultationStatus.completed;

  bool get isUpcoming => !isCancelled && !isCompleted;

  bool get isScheduled => mode == ConsultationMode.scheduled;

  /// It can be joined now: under way, or a booking from 10 minutes before
  /// until 30 minutes after it ends.
  bool canJoin(DateTime now) {
    if (status == ConsultationStatus.inProgress) return true;
    if (status != ConsultationStatus.scheduled) return false;
    final end = endsAt ?? startsAt.add(const Duration(minutes: 30));
    return now.isAfter(startsAt.subtract(const Duration(minutes: 10))) &&
        now.isBefore(end.add(const Duration(minutes: 30)));
  }

  String get doctorLabel {
    final n = (doctorName ?? '').trim();
    if (n.isEmpty) return '$specialty doctor';
    return n.toLowerCase().startsWith('dr') ? n : 'Dr. $n';
  }

  /// "Confirmed", "Waiting for payment"...
  String get statusLabel => switch (status) {
    ConsultationStatus.scheduled => 'Confirmed',
    ConsultationStatus.inProgress => 'In progress',
    ConsultationStatus.awaitingPayment => 'Awaiting payment',
    ConsultationStatus.matched => 'Doctor on the way',
    ConsultationStatus.completed => 'Completed',
    ConsultationStatus.cancelled || ConsultationStatus.unmatched => 'Cancelled',
    ConsultationStatus.requested => 'Finding a doctor',
  };

  /// Where tapping it goes.
  String get route => switch (status) {
    ConsultationStatus.completed => '/patient/visit/$id',
    ConsultationStatus.inProgress => '/patient/call/$id',
    ConsultationStatus.awaitingPayment => '/patient/consult/$id/pay',
    _ when isScheduled => '/patient/appointment/$id',
    _ => '/patient/waiting/$id',
  };

  factory AppointmentItem.fromMap(Map<String, dynamic> m) => AppointmentItem(
    id: m['consultation_id'] as String,
    doctorId: m['doctor_id'] as String?,
    doctorName: m['doctor_name'] as String?,
    doctorAvatar: m['doctor_avatar'] as String?,
    specialty: (m['specialty'] as String?) ?? 'General Practice',
    symptoms: (m['symptoms'] as String?) ?? '',
    status: enumFromDb(
      ConsultationStatus.values,
      m['status'] as String?,
      ConsultationStatus.scheduled,
    ),
    mode: enumFromDb(
      ConsultationMode.values,
      m['mode'] as String?,
      ConsultationMode.onDemand,
    ),
    startsAt: DateTime.parse(m['starts_at'] as String).toLocal(),
    endsAt: m['ends_at'] == null
        ? null
        : DateTime.parse(m['ends_at'] as String).toLocal(),
    fee: (m['fee'] as num?)?.toDouble(),
    facility: (m['practice_facility'] as String?)?.trim().isEmpty ?? true
        ? null
        : (m['practice_facility'] as String).trim(),
    myRating: (m['my_rating'] as num?)?.toInt(),
  );
}
