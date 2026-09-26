import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/medication.dart';

/// Medicine reminders. The database sends each reminder as a push (cron
/// every 5 minutes); the app lists courses and records doses taken.
class MedicationRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<List<MedicationSchedule>> mySchedules({
    bool activeOnly = false,
  }) async {
    var q = _client
        .from('medication_schedules')
        .select('*, dose_logs(*)')
        .eq('patient_id', _client.auth.currentUser!.id);
    if (activeOnly) q = q.eq('active', true);
    final rows = await q.order('created_at', ascending: false);
    return rows.map(MedicationSchedule.fromMap).toList();
  }

  Future<void> create({
    required String drugName,
    String? dosage,
    String? prescriptionItemId,
    required List<String> times,
    required int days,
  }) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(Duration(days: days - 1));
    String d(DateTime x) => x.toIso8601String().split('T').first;
    return _client.from('medication_schedules').insert({
      'drug_name': drugName,
      'dosage': dosage,
      'prescription_item_id': prescriptionItemId,
      'times': times,
      'start_on': d(start),
      'end_on': d(end),
    });
  }

  /// Answer a reminder ('taken' or 'skipped').
  Future<void> markDose(String doseLogId, {required bool taken}) => _client
      .from('dose_logs')
      .update({
        'status': taken ? 'taken' : 'skipped',
        'taken_at': taken ? DateTime.now().toUtc().toIso8601String() : null,
      })
      .eq('id', doseLogId);

  /// Record a dose taken without a reminder (e.g. taken early).
  Future<void> logTakenNow(String scheduleId) =>
      _client.from('dose_logs').upsert({
        'schedule_id': scheduleId,
        'due_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'taken',
        'taken_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> stop(String scheduleId) => _client
      .from('medication_schedules')
      .update({'active': false})
      .eq('id', scheduleId);
}
