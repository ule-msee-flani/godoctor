class ChemistProfile {
  const ChemistProfile({
    required this.userId,
    required this.businessName,
    this.locationLat,
    this.locationLng,
    this.registrationNumber,
    required this.verified,
    required this.verificationDocuments,
    this.locationName,
  });

  final String userId;
  final String businessName;
  final double? locationLat;
  final double? locationLng;
  final String? registrationNumber;
  final bool verified;
  final List<String> verificationDocuments;

  /// Readable place, e.g. "Ruiru, Kiambu, Kenya".
  final String? locationName;

  factory ChemistProfile.fromMap(Map<String, dynamic> map) => ChemistProfile(
    userId: map['user_id'] as String,
    businessName: (map['business_name'] as String?) ?? '',
    locationLat: (map['location_lat'] as num?)?.toDouble(),
    locationLng: (map['location_lng'] as num?)?.toDouble(),
    registrationNumber: map['registration_number'] as String?,
    verified: (map['verified'] as bool?) ?? false,
    verificationDocuments: List<String>.from(
      map['verification_documents'] as List? ?? const [],
    ),
    locationName: map['location_name'] as String?,
  );
}
