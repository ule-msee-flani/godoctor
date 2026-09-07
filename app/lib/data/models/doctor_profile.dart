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
