import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/consultation.dart';

/// Scheduled appointments. All writes go through SQL functions
/// (book/cancel/reschedule/start/submit_review) that enforce the rules
/// server-side: verified doctor, real open slot, no double-booking, only
/// the patient of a completed consultation can review.
class AppointmentRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Books [start] with [doctorId]. If [flaggedEmergency] is true the request
  /// is recorded for audit and NOT booked (the caller must already have shown
  /// the emergency stop screen).
  Future<String> book({
    required String doctorId,
    required DateTime start,
    required String specialty,
    required String reason,
    bool flaggedEmergency = false,
  }) async {
    final id = await _client.rpc(
      'book_appointment',
      params: {
        'p_doctor_id': doctorId,
        'p_start': start.toUtc().toIso8601String(),
        'p_specialty': specialty,
        'p_reason': reason,
        'p_flagged_emergency': flaggedEmergency,
      },
    );
    return id as String;
  }

  Future<void> cancel(String consultationId) =>
      _client.rpc('cancel_appointment', params: {'p_id': consultationId});

  Future<void> reschedule(String consultationId, DateTime newStart) =>
      _client.rpc(
        'reschedule_appointment',
        params: {
          'p_id': consultationId,
          'p_new_start': newStart.toUtc().toIso8601String(),
        },
      );

  /// Opens the session (allowed from 10 minutes before the start).
  Future<void> start(String consultationId) =>
      _client.rpc('start_appointment', params: {'p_id': consultationId});

  Future<void> submitReview({
    required String consultationId,
    required int rating,
    String? comment,
  }) => _client.rpc(
    'submit_review',
    params: {
      'p_consultation_id': consultationId,
      'p_rating': rating,
      'p_comment': comment,
    },
  );

  Future<Consultation?> fetch(String consultationId) async {
    final row = await _client
        .from('consultations')
        .select()
        .eq('id', consultationId)
        .maybeSingle();
    return row == null ? null : Consultation.fromMap(row);
  }

  /// Upcoming and in-progress appointments, soonest first.
  Future<List<Consultation>> upcomingForPatient(String patientId) async {
    final rows = await _client
        .from('consultations')
        .select()
        .eq('patient_id', patientId)
        .eq('mode', 'scheduled')
        .inFilter('status', ['scheduled', 'in_progress'])
        .order('scheduled_for');
    return rows.map((r) => Consultation.fromMap(r)).toList();
  }

  Future<List<Consultation>> upcomingForDoctor(String doctorId) async {
    final rows = await _client
        .from('consultations')
        .select()
        .eq('doctor_id', doctorId)
        .eq('mode', 'scheduled')
        .inFilter('status', ['scheduled', 'in_progress'])
        .order('scheduled_for');
    return rows.map((r) => Consultation.fromMap(r)).toList();
  }

  /// Has this patient already reviewed [consultationId]?
  Future<bool> hasReviewed(String consultationId) async {
    final rows = await _client
        .from('reviews')
        .select('id')
        .eq('consultation_id', consultationId)
        .limit(1);
    return rows.isNotEmpty;
  }

  /// The stars I gave this consultation, or null if I haven't rated it.
  Future<int?> myRating(String consultationId) async {
    final rows = await _client
        .from('reviews')
        .select('rating')
        .eq('consultation_id', consultationId)
        .limit(1);
    return rows.isEmpty ? null : (rows.first['rating'] as num?)?.toInt();
  }
}
