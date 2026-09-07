class PatientProfile {
  const PatientProfile({
    required this.userId,
    required this.name,
    this.dateOfBirth,
    this.locationLat,
    this.locationLng,
    this.allergies,
    this.currentMedications,
    this.chronicConditions,
  });

  final String userId;
  final String name;
  final DateTime? dateOfBirth;
  final double? locationLat;
  final double? locationLng;
  final String? allergies;
  final String? currentMedications;
  final String? chronicConditions;

  factory PatientProfile.fromMap(Map<String, dynamic> map) => PatientProfile(
    userId: map['user_id'] as String,
    name: (map['name'] as String?) ?? '',
    dateOfBirth: map['date_of_birth'] != null
        ? DateTime.tryParse(map['date_of_birth'] as String)
        : null,
    locationLat: (map['location_lat'] as num?)?.toDouble(),
    locationLng: (map['location_lng'] as num?)?.toDouble(),
    allergies: map['allergies'] as String?,
    currentMedications: map['current_medications'] as String?,
    chronicConditions: map['chronic_conditions'] as String?,
  );

  Map<String, dynamic> toUpdateMap() => {
    'name': name,
    if (dateOfBirth != null)
      'date_of_birth': dateOfBirth!.toIso8601String().split('T').first,
    'location_lat': locationLat,
    'location_lng': locationLng,
    'allergies': allergies,
    'current_medications': currentMedications,
    'chronic_conditions': chronicConditions,
  };
}
