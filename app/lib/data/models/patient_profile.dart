class PatientProfile {
  const PatientProfile({
    required this.userId,
    required this.name,
    this.dateOfBirth,
    this.locationLat,
    this.locationLng,
    this.locationName,
    this.locationDetails,
    this.allergies,
    this.currentMedications,
    this.chronicConditions,
    this.bloodGroup,
    this.heightCm,
    this.weightKg,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String userId;
  final String name;
  final DateTime? dateOfBirth;
  final double? locationLat;
  final double? locationLng;

  /// Readable place, e.g. "Ruiru, Kiambu, Kenya".
  final String? locationName;

  /// Landmark / house / gate, for deliveries.
  final String? locationDetails;
  final String? allergies;
  final String? currentMedications;
  final String? chronicConditions;
  final String? bloodGroup;
  final double? heightCm;
  final double? weightKg;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  bool get hasLocation => locationLat != null && locationLng != null;

  factory PatientProfile.fromMap(Map<String, dynamic> map) => PatientProfile(
    userId: map['user_id'] as String,
    name: (map['name'] as String?) ?? '',
    dateOfBirth: map['date_of_birth'] != null
        ? DateTime.tryParse(map['date_of_birth'] as String)
        : null,
    locationLat: (map['location_lat'] as num?)?.toDouble(),
    locationLng: (map['location_lng'] as num?)?.toDouble(),
    locationName: map['location_name'] as String?,
    locationDetails: map['location_details'] as String?,
    allergies: map['allergies'] as String?,
    currentMedications: map['current_medications'] as String?,
    chronicConditions: map['chronic_conditions'] as String?,
    bloodGroup: map['blood_group'] as String?,
    heightCm: (map['height_cm'] as num?)?.toDouble(),
    weightKg: (map['weight_kg'] as num?)?.toDouble(),
    emergencyContactName: map['emergency_contact_name'] as String?,
    emergencyContactPhone: map['emergency_contact_phone'] as String?,
  );

  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    if (dateOfBirth != null)
      'date_of_birth': dateOfBirth!.toIso8601String().split('T').first,
    'location_lat': locationLat,
    'location_lng': locationLng,
    'location_name': locationName,
    'location_details': locationDetails,
    'allergies': allergies,
    'current_medications': currentMedications,
    'chronic_conditions': chronicConditions,
    'blood_group': bloodGroup,
    'height_cm': heightCm,
    'weight_kg': weightKg,
    'emergency_contact_name': emergencyContactName,
    'emergency_contact_phone': emergencyContactPhone,
  };
}
