import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/consultation.dart';

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
}
