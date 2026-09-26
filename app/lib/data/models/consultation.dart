import 'enums.dart';

class Consultation {
  const Consultation({
    required this.id,
    required this.patientId,
    this.doctorId,
    required this.specialtyRequested,
    required this.symptomSummary,
    required this.status,
    this.videoSessionId,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    this.mode = ConsultationMode.onDemand,
    this.scheduledFor,
    this.scheduledEnd,
    this.feeAmount,
    this.paymentDueAt,
  });

  final String id;
  final String patientId;
  final String? doctorId;
  final String specialtyRequested;
  final String symptomSummary;
  final ConsultationStatus status;
  final String? videoSessionId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final ConsultationMode mode;
  final DateTime? scheduledFor;
  final DateTime? scheduledEnd;
  final double? feeAmount;

  /// While awaiting payment: when the doctor reservation lapses.
  final DateTime? paymentDueAt;

  bool get isScheduled => mode == ConsultationMode.scheduled;

  /// A booked appointment can be opened from 10 minutes before it starts
  /// until 30 minutes after it ends (mirrors start_appointment() in SQL).
  bool get canStartNow {
    if (!isScheduled || scheduledFor == null || scheduledEnd == null) {
      return false;
    }
    final now = DateTime.now();
    return now.isAfter(scheduledFor!.subtract(const Duration(minutes: 10))) &&
        now.isBefore(scheduledEnd!.add(const Duration(minutes: 30)));
  }

  factory Consultation.fromMap(Map<String, dynamic> map) => Consultation(
    id: map['id'] as String,
    patientId: map['patient_id'] as String,
    doctorId: map['doctor_id'] as String?,
    specialtyRequested: (map['specialty_requested'] as String?) ?? '',
    symptomSummary: (map['symptom_summary'] as String?) ?? '',
    status: enumFromDb(
      ConsultationStatus.values,
      map['status'] as String?,
      ConsultationStatus.requested,
    ),
    videoSessionId: map['video_session_id'] as String?,
    startedAt: map['started_at'] != null
        ? DateTime.tryParse(map['started_at'] as String)
        : null,
    endedAt: map['ended_at'] != null
        ? DateTime.tryParse(map['ended_at'] as String)
        : null,
    createdAt: DateTime.parse(map['created_at'] as String),
    mode: enumFromDb(
      ConsultationMode.values,
      map['mode'] as String?,
      ConsultationMode.onDemand,
    ),
    scheduledFor: map['scheduled_for'] != null
        ? DateTime.tryParse(map['scheduled_for'] as String)?.toLocal()
        : null,
    scheduledEnd: map['scheduled_end'] != null
        ? DateTime.tryParse(map['scheduled_end'] as String)?.toLocal()
        : null,
    feeAmount: (map['fee_amount'] as num?)?.toDouble(),
    paymentDueAt: map['payment_due_at'] != null
        ? DateTime.tryParse(map['payment_due_at'] as String)?.toLocal()
        : null,
  );
}

class IntakeForm {
  const IntakeForm({
    required this.consultationId,
    required this.symptoms,
    this.duration,
    this.severity,
    required this.flaggedEmergency,
  });

  final String consultationId;
  final String symptoms;
  final String? duration;
  final String? severity;
  final bool flaggedEmergency;

  factory IntakeForm.fromMap(Map<String, dynamic> map) => IntakeForm(
    consultationId: map['consultation_id'] as String,
    symptoms: (map['symptoms'] as String?) ?? '',
    duration: map['duration'] as String?,
    severity: map['severity'] as String?,
    flaggedEmergency: (map['flagged_emergency'] as bool?) ?? false,
  );
}

class ConsultationOffer {
  const ConsultationOffer({
    required this.id,
    required this.consultationId,
    required this.doctorId,
    required this.status,
    required this.offeredAt,
    this.respondedAt,
    required this.expiresAt,
  });

  final String id;
  final String consultationId;
  final String doctorId;
  final OfferStatus status;
  final DateTime offeredAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;

  factory ConsultationOffer.fromMap(Map<String, dynamic> map) =>
      ConsultationOffer(
        id: map['id'] as String,
        consultationId: map['consultation_id'] as String,
        doctorId: map['doctor_id'] as String,
        status: enumFromDb(
          OfferStatus.values,
          map['status'] as String?,
          OfferStatus.pending,
        ),
        offeredAt: DateTime.parse(map['offered_at'] as String),
        respondedAt: map['responded_at'] != null
            ? DateTime.tryParse(map['responded_at'] as String)
            : null,
        expiresAt: DateTime.parse(map['expires_at'] as String),
      );
}
