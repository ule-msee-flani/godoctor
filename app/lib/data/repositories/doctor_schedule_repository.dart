import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/public_doctor.dart';

/// A doctor managing their own bookable hours (weekly windows + time off).
class DoctorScheduleRepository {
  SupabaseClient get _client => SupabaseService.client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<AvailabilityWindow>> fetchAvailability() async {
    final rows = await _client
        .from('doctor_availability')
        .select()
        .eq('doctor_id', _uid)
        .order('weekday')
        .order('start_time');
    return rows.map((r) => AvailabilityWindow.fromMap(r)).toList();
  }

  Future<void> addWindow(AvailabilityWindow w) =>
      _client.from('doctor_availability').insert({
        'doctor_id': _uid,
        'weekday': w.weekday,
        'start_time': w.start,
        'end_time': w.end,
        'slot_minutes': w.slotMinutes,
      });

  Future<void> deleteWindow(String id) =>
      _client.from('doctor_availability').delete().eq('id', id);

  Future<List<TimeOff>> fetchTimeOff() async {
    final rows = await _client
        .from('doctor_time_off')
        .select()
        .eq('doctor_id', _uid)
        .gte('ends_at', DateTime.now().toUtc().toIso8601String())
        .order('starts_at');
    return rows.map((r) => TimeOff.fromMap(r)).toList();
  }

  Future<void> addTimeOff({
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) => _client.from('doctor_time_off').insert({
    'doctor_id': _uid,
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'reason': reason,
  });

  Future<void> deleteTimeOff(String id) =>
      _client.from('doctor_time_off').delete().eq('id', id);
}
