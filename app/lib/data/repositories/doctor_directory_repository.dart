import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/public_chemist.dart';
import '../models/public_doctor.dart';
import '../models/my_doctor.dart';

/// The certified-doctor directory: search, public profiles, open slots and
/// public reviews. Everything goes through SQL functions that expose only
/// safe columns for licence-verified doctors.
class DoctorDirectoryRepository {
  SupabaseClient get _client => SupabaseService.client;

  /// Consultations completed and patients seen, for the doctor's profile.
  Future<DoctorPublicStats> publicStats(String doctorId) async {
    final res = await _client.rpc(
      'doctor_public_stats',
      params: {'p_doctor': doctorId},
    );
    return DoctorPublicStats.fromMap(res as Map<String, dynamic>?);
  }

  /// Open appointment slots per day for [doctorIds], from today, for
  /// [days] days: doctor -> day -> count.
  Future<Map<String, Map<DateTime, int>>> slotCounts(
    List<String> doctorIds, {
    int days = 5,
  }) async {
    if (doctorIds.isEmpty) return const {};
    final rows =
        await _client.rpc(
              'doctor_slot_counts',
              params: {
                'p_doctors': doctorIds.take(50).toList(),
                'p_days': days,
              },
            )
            as List;
    final out = <String, Map<DateTime, int>>{};
    for (final r in rows.cast<Map<String, dynamic>>()) {
      final day = DateTime.parse(r['day'] as String);
      (out[r['doctor_id'] as String] ??= {})[DateTime(
        day.year,
        day.month,
        day.day,
      )] = (r['slots'] as num)
          .toInt();
    }
    return out;
  }

  /// Average, stars per level and sub-scores for a doctor or pharmacy.
  Future<RatingBreakdown> ratingBreakdown(String userId) async {
    final res = await _client.rpc(
      'rating_breakdown',
      params: {'p_user': userId},
    );
    return RatingBreakdown.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Doctors I've seen and doctors I saved, saved first.
  Future<List<MyDoctor>> myDoctors() async {
    final rows = await _client.rpc('my_doctors') as List;
    return [for (final r in rows) MyDoctor.fromMap(r as Map<String, dynamic>)];
  }

  /// Save (or unsave) a doctor to "My doctors".
  Future<void> setFavorite(String doctorId, bool favorite) async {
    final me = _client.auth.currentUser!.id;
    if (favorite) {
      await _client.from('favorite_doctors').upsert({
        'patient_id': me,
        'doctor_id': doctorId,
      });
    } else {
      await _client
          .from('favorite_doctors')
          .delete()
          .eq('patient_id', me)
          .eq('doctor_id', doctorId);
    }
  }

  /// What patients said about a pharmacy, newest first (no names).
  Future<List<DoctorReview>> chemistReviews(
    String chemistId, {
    int limit = 20,
  }) async {
    final rows = await _client.rpc(
      'chemist_reviews',
      params: {'p_chemist': chemistId, 'p_limit': limit},
    );
    return (rows as List)
        .map((r) => DoctorReview.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Every verified pharmacy, for patients to browse.
  Future<List<PublicChemist>> listChemists() async {
    final rows = await _client.rpc('public_chemists') as List;
    return [
      for (final r in rows) PublicChemist.fromMap(r as Map<String, dynamic>),
    ];
  }

  /// A verified pharmacy's public page, or null.
  Future<PublicChemist?> getChemist(String chemistId) async {
    final rows =
        await _client.rpc(
              'chemist_public_profile',
              params: {'p_chemist': chemistId},
            )
            as List;
    return rows.isEmpty
        ? null
        : PublicChemist.fromMap(rows.first as Map<String, dynamic>);
  }

  Future<List<PublicDoctor>> search({
    String? query,
    String? specialty,
    double? maxFee,
    String? language,
    String? gender,
    bool availableNow = false,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'search_doctors',
      params: {
        'p_query': (query == null || query.trim().isEmpty)
            ? null
            : query.trim(),
        'p_specialty': specialty,
        'p_max_fee': maxFee,
        'p_language': language,
        'p_gender': gender,
        'p_available_now': availableNow,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return (rows as List)
        .map((r) => PublicDoctor.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<PublicDoctor?> getDoctor(String doctorId) async {
    final rows = await _client.rpc(
      'get_public_doctor',
      params: {'p_id': doctorId},
    );
    final list = rows as List;
    return list.isEmpty
        ? null
        : PublicDoctor.fromMap(list.first as Map<String, dynamic>);
  }

  /// Open slots for [doctorId] on each calendar day from [from] to [to]
  /// (inclusive, max 31 days). Slots are computed in Kenya time on the server.
  Future<List<TimeSlot>> openSlots(
    String doctorId,
    DateTime from,
    DateTime to,
  ) async {
    final rows = await _client.rpc(
      'doctor_open_slots',
      params: {
        'p_doctor_id': doctorId,
        'p_from': _dateOnly(from),
        'p_to': _dateOnly(to),
      },
    );
    return (rows as List)
        .map((r) => TimeSlot.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<DoctorReview>> reviews(
    String doctorId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _client.rpc(
      'doctor_reviews',
      params: {'p_doctor_id': doctorId, 'p_limit': limit, 'p_offset': offset},
    );
    return (rows as List)
        .map((r) => DoctorReview.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Public URL for a doctor's avatar, or null if they haven't set one.
  String? avatarUrl(String? path) => (path == null || path.isEmpty)
      ? null
      : _client.storage.from('avatars').getPublicUrl(path);

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
