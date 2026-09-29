import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/consultation.dart';
import '../models/appointment_item.dart';
import '../models/enums.dart';
import '../models/visit.dart';

/// Consultation lifecycle: intake -> matching -> offer/accept -> in-progress.
///
/// Matching itself (rank-by-longest-idle-time, offer/decline/timeout chain)
/// lives in Postgres (`request_consultation`, `respond_to_offer`,
/// `offer_next_candidate`, `expire_stale_offers` -- see
/// supabase/migrations/0008_functions_and_triggers.sql) so it stays
/// consistent no matter which client calls it. This repo just calls those
/// RPCs and exposes Realtime streams for the UI to react to.
class ConsultationRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Returns the new consultation's id. If [flaggedEmergency] is true, the
  /// consultation is created (for audit) but immediately cancelled and no
  /// matching is attempted -- the caller must have already shown the
  /// emergency hard-stop UI before calling this.
  Future<String> requestConsultation({
    required String specialty,
    required String symptomSummary,
    required String symptoms,
    String? duration,
    String? severity,
    required bool flaggedEmergency,
  }) async {
    final result = await _client.rpc(
      'request_consultation',
      params: {
        'p_specialty': specialty,
        'p_symptom_summary': symptomSummary,
        'p_symptoms': symptoms,
        'p_duration': duration,
        'p_severity': severity,
        'p_flagged_emergency': flaggedEmergency,
      },
    );
    return result as String;
  }

  Future<void> respondToOffer({
    required String offerId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_to_offer',
      params: {'p_offer_id': offerId, 'p_accept': accept},
    );
  }

  /// Step 2 -> 3: the patient picks a doctor. The doctor is reserved for 10
  /// minutes while the patient pays. With [flaggedEmergency] the request is
  /// only recorded for audit (the caller shows the emergency screen).
  Future<String> requestDoctor({
    required String doctorId,
    required String specialty,
    required String symptoms,
    bool flaggedEmergency = false,
  }) async {
    final id = await _client.rpc(
      'request_doctor',
      params: {
        'p_doctor_id': doctorId,
        'p_specialty': specialty,
        'p_symptoms': symptoms,
        'p_flagged_emergency': flaggedEmergency,
      },
    );
    return id as String;
  }

  /// SIMULATED M-Pesa payment (real Daraja integration comes later). Starts
  /// the consultation.
  Future<void> payForConsultation(String consultationId) =>
      _client.rpc('pay_for_consultation', params: {'p_id': consultationId});

  /// Patient backs out before paying; the doctor is released.
  Future<void> cancelRequest(String consultationId) => _client.rpc(
    'cancel_consultation_request',
    params: {'p_id': consultationId},
  );

  /// The doctor's current on-demand patient(s): being paid for, or in progress.
  Stream<List<Consultation>> watchActiveForDoctor(String doctorId) {
    return _client
        .from('consultations')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .map(
          (rows) => rows
              .map((r) => Consultation.fromMap(r))
              .where(
                (c) =>
                    !c.isScheduled &&
                    (c.status == ConsultationStatus.awaitingPayment ||
                        c.status == ConsultationStatus.matched ||
                        c.status == ConsultationStatus.inProgress),
              )
              .toList(),
        );
  }

  /// The patient's on-demand consultation that is still under way (being
  /// matched, waiting for payment, or on the call), live; null when none.
  Stream<Consultation?> watchActiveForPatient(String patientId) {
    return _client
        .from('consultations')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('created_at')
        .limit(10)
        .map(
          (rows) => rows
              .map((r) => Consultation.fromMap(r))
              .where(
                (c) =>
                    !c.isScheduled &&
                    (c.status == ConsultationStatus.requested ||
                        c.status == ConsultationStatus.matched ||
                        c.status == ConsultationStatus.awaitingPayment ||
                        c.status == ConsultationStatus.inProgress),
              )
              .firstOrNull,
        );
  }

  /// A patient watching their own consultation for status changes
  /// (requested -> matched/unmatched -> in_progress -> completed).
  Stream<Consultation?> watchConsultation(String consultationId) {
    return _client
        .from('consultations')
        .stream(primaryKey: ['id'])
        .eq('id', consultationId)
        .map((rows) => rows.isEmpty ? null : Consultation.fromMap(rows.first));
  }

  /// A doctor's incoming-offers queue -- realtime, filtered to their id.
  Stream<List<ConsultationOffer>> watchOffersForDoctor(String doctorId) {
    return _client
        .from('consultation_offers')
        .stream(primaryKey: ['id'])
        .eq('doctor_id', doctorId)
        .order('offered_at')
        .map(
          (rows) => rows
              .map((r) => ConsultationOffer.fromMap(r))
              .where((o) => o.status.name == 'pending')
              .toList(),
        );
  }

  Future<IntakeForm?> fetchIntakeForm(String consultationId) async {
    final row = await _client
        .from('intake_forms')
        .select()
        .eq('consultation_id', consultationId)
        .maybeSingle();
    return row == null ? null : IntakeForm.fromMap(row);
  }

  Future<Consultation?> fetchById(String consultationId) async {
    final row = await _client
        .from('consultations')
        .select()
        .eq('id', consultationId)
        .maybeSingle();
    return row == null ? null : Consultation.fromMap(row);
  }

  /// Every appointment and visit (upcoming, completed, cancelled), newest
  /// first, with the doctor's name, photo and hospital.
  Future<List<AppointmentItem>> myAppointments() async {
    final rows = await _client.rpc('patient_appointments') as List<dynamic>;
    return [
      for (final r in rows) AppointmentItem.fromMap(r as Map<String, dynamic>),
    ];
  }

  /// My visits with the doctor's name and photo, how many prescriptions
  /// came out of each, and whether I've rated it. Newest first.
  Future<List<Visit>> myVisits() async {
    final rows = await _client.rpc('patient_visits') as List<dynamic>;
    return [for (final r in rows) Visit.fromMap(r as Map<String, dynamic>)];
  }

  Future<List<Consultation>> fetchHistoryForPatient(String patientId) async {
    final rows = await _client
        .from('consultations')
        .select()
        .eq('patient_id', patientId)
        .order('created_at', ascending: false);
    return rows.map((r) => Consultation.fromMap(r)).toList();
  }

  Future<List<Consultation>> fetchHistoryForDoctor(String doctorId) async {
    final rows = await _client
        .from('consultations')
        .select()
        .eq('doctor_id', doctorId)
        .order('created_at', ascending: false);
    return rows.map((r) => Consultation.fromMap(r)).toList();
  }

  /// Marks the consultation complete and flips the doctor back to available
  /// (see `complete_consultation` in 0008_functions_and_triggers.sql).
  Future<void> completeConsultation(String consultationId) async {
    await _client.rpc(
      'complete_consultation',
      params: {'p_consultation_id': consultationId},
    );
  }

  /// The patient's wish for the doctor's camera during the call.
  Future<void> setVideoPreference(
    String consultationId, {
    required bool doctorVideo,
  }) => _client.rpc(
    'set_video_preference',
    params: {
      'p_consultation_id': consultationId,
      'p_doctor_video': doctorVideo,
    },
  );

  /// Doctor opened the call: the patient's waiting room turns into the call.
  Future<void> markDoctorJoined(String consultationId) => _client.rpc(
    'mark_doctor_joined',
    params: {'p_consultation_id': consultationId},
  );

  /// The doctor's plain-language summary for the patient's visit card.
  Future<void> saveVisitSummary(
    String consultationId, {
    String? summary,
    String? redFlags,
    DateTime? followUpOn,
  }) => _client.rpc(
    'save_visit_summary',
    params: {
      'p_consultation_id': consultationId,
      'p_summary': summary,
      'p_red_flags': redFlags,
      'p_follow_up_on': followUpOn?.toIso8601String().split('T').first,
    },
  );

  // --- Voice notes (private bucket) ---

  /// Uploads the patient's recorded description; returns the storage path.
  Future<String> uploadVoiceNote({
    required String patientId,
    required Uint8List bytes,
    required String fileExt,
    required String contentType,
  }) async {
    final path = '$patientId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    await _client.storage
        .from('voice-notes')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }

  Future<void> attachVoiceNote(String consultationId, String path) =>
      _client.rpc(
        'attach_voice_note',
        params: {'p_consultation_id': consultationId, 'p_path': path},
      );

  /// Short-lived link to play a voice note (patient or their doctor only).
  Future<String> voiceNoteUrl(String path) =>
      _client.storage.from('voice-notes').createSignedUrl(path, 60 * 30);

  // --- Doctor cockpit ---

  /// Today (Nairobi): patients seen, earnings, rating, open chats.
  Future<Map<String, dynamic>> doctorTodayStats() async =>
      (await _client.rpc('doctor_today_stats')) as Map<String, dynamic>;
}
