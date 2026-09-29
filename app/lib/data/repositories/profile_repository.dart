import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../models/app_user.dart';
import '../models/chemist_profile.dart';
import '../models/doctor_profile.dart';
import '../models/patient_profile.dart';
import '../models/patient_card.dart';
import '../models/health_reading.dart';

class ProfileRepository {
  SupabaseClient get _client => SupabaseService.client;

  Future<AppUser?> fetchUser(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AppUser.fromMap(row);
  }

  Future<PatientProfile?> fetchPatientProfile(String userId) async {
    final row = await _client
        .from('patient_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : PatientProfile.fromMap(row);
  }

  Future<DoctorProfile?> fetchDoctorProfile(String userId) async {
    final row = await _client
        .from('doctor_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : DoctorProfile.fromMap(row);
  }

  Future<ChemistProfile?> fetchChemistProfile(String userId) async {
    final row = await _client
        .from('chemist_profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : ChemistProfile.fromMap(row);
  }

  Future<void> updatePatientProfile(PatientProfile profile) async {
    await _client
        .from('patient_profiles')
        .update(profile.toUpdateMap())
        .eq('user_id', profile.userId);
  }

  Future<void> updateDoctorRegistration({
    required String userId,
    required String name,
    required List<String> specialties,
    required String licenseNumber,
    DateTime? licenseExpiry,
    List<String> verificationDocuments = const [],
  }) async {
    await _client
        .from('doctor_profiles')
        .update({
          'name': name,
          'specialties': specialties,
          'license_number': licenseNumber,
          'license_expiry': licenseExpiry?.toIso8601String().split('T').first,
          'verification_documents': verificationDocuments,
        })
        .eq('user_id', userId);
  }

  /// The fields patients see in the directory. (Licence details are edited
  /// separately during onboarding; verification stays admin-only.)
  Future<void> updateDoctorPublicProfile({
    required String userId,
    String? bio,
    double? consultationFee,
    required List<String> languages,
    String? gender,
    int? yearsExperience,
    String? avatarPath,
  }) async {
    await _client
        .from('doctor_profiles')
        .update({
          'bio': bio,
          'consultation_fee': consultationFee,
          'languages': languages,
          'gender': gender,
          'years_experience': yearsExperience,
          'avatar_url': ?avatarPath,
        })
        .eq('user_id', userId);
  }

  /// Uploads a new profile photo to the public `avatars` bucket (each user
  /// may only write inside their own folder) and returns the storage path.
  Future<String> uploadDoctorAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final ext = fileExt.toLowerCase().replaceAll('.', '');
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage
        .from('avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );
    return path;
  }

  /// Uploads a profile photo for any user (patient, doctor, chemist) and
  /// makes it their current one. Returns the storage path.
  Future<String> changeAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    var ext = fileExt.toLowerCase().replaceAll('.', '');
    if (ext == 'jpg') ext = 'jpeg';
    final path = await uploadDoctorAvatar(
      userId: userId,
      bytes: bytes,
      fileExt: ext,
    );
    // A trigger copies this to doctor_profiles for the doctor directory.
    await _client.from('users').update({'avatar_url': path}).eq('id', userId);
    return path;
  }

  /// Public URL of a photo in the `avatars` bucket.
  /// Saves the welcome path's answers for the caller's role and marks it
  /// done. Keys the server doesn't know for the role are ignored.
  Future<void> completeOnboarding(Map<String, Object?> answers) =>
      _client.rpc('complete_onboarding', params: {'p': answers});

  /// "The details I've given are genuine" on a doctor's or pharmacy's
  /// registration.
  Future<void> attestRegistration() => _client.rpc('attest_registration');

  /// A patient's card for their doctor or pharmacy (the server checks the
  /// relationship).
  Future<PatientCard?> patientCard(String patientId) async {
    final rows =
        await _client.rpc('patient_card', params: {'p_patient': patientId})
            as List;
    return rows.isEmpty
        ? null
        : PatientCard.fromMap(rows.first as Map<String, dynamic>);
  }

  /// My readings of one [kind] ('bp', 'sugar', 'weight'), newest first.
  Future<List<HealthReading>> readings({String? kind, int limit = 60}) async {
    var q = _client.from('health_readings').select();
    if (kind != null) q = q.eq('kind', kind);
    final rows = await q.order('taken_at', ascending: false).limit(limit);
    return rows.map(HealthReading.fromMap).toList();
  }

  Future<void> addReading({
    required String kind,
    required double value,
    double? value2,
    String? context,
    DateTime? takenAt,
  }) => _client.from('health_readings').insert({
    'patient_id': _client.auth.currentUser!.id,
    'kind': kind,
    'value': value,
    'value2': ?value2,
    'context': ?context,
    'taken_at': (takenAt ?? DateTime.now()).toUtc().toIso8601String(),
  });

  Future<void> deleteReading(String id) =>
      _client.from('health_readings').delete().eq('id', id);

  /// A 15-minute code for my health card's QR.
  Future<({String code, DateTime expiresAt})> createShareCode() async {
    final rows = await _client.rpc('create_patient_share_code') as List;
    final r = rows.first as Map<String, dynamic>;
    return (
      code: r['code'] as String,
      expiresAt: DateTime.parse(r['expires_at'] as String).toLocal(),
    );
  }

  /// A doctor or pharmacy opens a patient's card from their QR code.
  Future<PatientCard?> patientCardByCode(String code) async {
    final rows =
        await _client.rpc('patient_card_by_code', params: {'p_code': code})
            as List;
    return rows.isEmpty
        ? null
        : PatientCard.fromMap(rows.first as Map<String, dynamic>);
  }

  /// "How are you feeling today?" (great / good / okay / low / unwell).
  Future<void> logMood(String mood) => _client.from('mood_checkins').insert({
    'patient_id': _client.auth.currentUser!.id,
    'mood': mood,
  });

  /// Well guide: when I last had each preventive check (key -> date).
  Future<Map<String, DateTime>> preventiveChecks() async {
    final rows = await _client
        .from('preventive_checks')
        .select('check_key, last_done');
    return {
      for (final r in rows)
        r['check_key'] as String: DateTime.parse(r['last_done'] as String),
    };
  }

  Future<void> markPreventiveCheck(String key, DateTime done) =>
      _client.from('preventive_checks').upsert({
        'patient_id': _client.auth.currentUser!.id,
        'check_key': key,
        'last_done':
            '${done.year}-${done.month.toString().padLeft(2, '0')}-'
            '${done.day.toString().padLeft(2, '0')}',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

  Future<void> clearPreventiveCheck(String key) => _client
      .from('preventive_checks')
      .delete()
      .eq('patient_id', _client.auth.currentUser!.id)
      .eq('check_key', key);

  String? avatarUrl(String? path) => (path == null || path.isEmpty)
      ? null
      : _client.storage.from('avatars').getPublicUrl(path);

  Future<void> updateContactPhone(String userId, String? phone) =>
      _client.from('users').update({'contact_phone': phone}).eq('id', userId);

  /// "I'm here": lets family see who is online for a family session.
  Future<void> touchPresence() => _client.rpc('touch_presence');

  Future<void> updateChemistLocation({
    required String userId,
    required String name,
    required double lat,
    required double lng,
  }) => _client
      .from('chemist_profiles')
      .update({'location_name': name, 'location_lat': lat, 'location_lng': lng})
      .eq('user_id', userId);

  Future<void> updateChemistRegistration({
    required String userId,
    required String businessName,
    required String registrationNumber,
    double? locationLat,
    double? locationLng,
    String? locationName,
    List<String> verificationDocuments = const [],
  }) async {
    await _client
        .from('chemist_profiles')
        .update({
          'business_name': businessName,
          'registration_number': registrationNumber,
          'location_lat': locationLat,
          'location_lng': locationLng,
          'location_name': locationName,
          'verification_documents': verificationDocuments,
        })
        .eq('user_id', userId);
  }

  Future<void> setDoctorAvailability(bool available) async {
    await _client.rpc(
      'set_doctor_availability',
      params: {'p_available': available},
    );
  }

  // --- Admin verification queue ---

  Future<List<DoctorProfile>> fetchPendingDoctors() async {
    final rows = await _client
        .from('doctor_profiles')
        .select()
        .eq('license_verified', false)
        .order('user_id');
    return rows.map((r) => DoctorProfile.fromMap(r)).toList();
  }

  Future<List<ChemistProfile>> fetchPendingChemists() async {
    final rows = await _client
        .from('chemist_profiles')
        .select()
        .eq('verified', false)
        .order('user_id');
    return rows.map((r) => ChemistProfile.fromMap(r)).toList();
  }

  Future<void> adminSetDoctorVerified(String userId, bool verified) async {
    await _client.rpc(
      'admin_set_doctor_verified',
      params: {'target_user_id': userId, 'verified': verified},
    );
  }

  Future<void> adminSetChemistVerified(String userId, bool verified) async {
    await _client.rpc(
      'admin_set_chemist_verified',
      params: {'target_user_id': userId, 'verified': verified},
    );
  }
}
