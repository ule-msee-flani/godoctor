import 'enums.dart';

class DoctorProfile {
  const DoctorProfile({
    required this.userId,
    required this.name,
    required this.specialties,
    this.licenseNumber,
    required this.licenseVerified,
    this.licenseExpiry,
    required this.verificationDocuments,
    required this.status,
    required this.ratingAvg,
    this.ratingCount = 0,
    this.bio,
    this.consultationFee,
    this.languages = const [],
    this.gender,
    this.yearsExperience,
    this.avatarPath,
  });

  final String userId;
  final String name;
  final List<String> specialties;
  final String? licenseNumber;
  final bool licenseVerified;
  final DateTime? licenseExpiry;
  final List<String> verificationDocuments;
  final DoctorStatus status;
  final double ratingAvg;
  final int ratingCount;
  final String? bio;
  final double? consultationFee;
  final List<String> languages;
  final String? gender;
  final int? yearsExperience;

  /// Path inside the public `avatars` storage bucket.
  final String? avatarPath;

  factory DoctorProfile.fromMap(Map<String, dynamic> map) => DoctorProfile(
    userId: map['user_id'] as String,
    name: (map['name'] as String?) ?? '',
    specialties: List<String>.from(map['specialties'] as List? ?? const []),
    licenseNumber: map['license_number'] as String?,
    licenseVerified: (map['license_verified'] as bool?) ?? false,
    licenseExpiry: map['license_expiry'] != null
        ? DateTime.tryParse(map['license_expiry'] as String)
        : null,
    verificationDocuments: List<String>.from(
      map['verification_documents'] as List? ?? const [],
    ),
    status: enumFromDb(
      DoctorStatus.values,
      map['status'] as String?,
      DoctorStatus.offline,
    ),
    ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
    bio: map['bio'] as String?,
    consultationFee: (map['consultation_fee'] as num?)?.toDouble(),
    languages: List<String>.from(map['languages'] as List? ?? const []),
    gender: map['gender'] as String?,
    yearsExperience: (map['years_experience'] as num?)?.toInt(),
    avatarPath: map['avatar_url'] as String?,
  );
}

/// A short list of common specialties for the registration/matching UI.
/// 'General Practice' is required for the doctor-matching fallback logic.
const kSpecialties = [
  'General Practice',
  'Pediatrics',
  'Obstetrics & Gynaecology',
  'Internal Medicine',
  'Dermatology',
  'Psychiatry/Mental Health',
  'Cardiology',
  'ENT',
  'Orthopedics',
];
