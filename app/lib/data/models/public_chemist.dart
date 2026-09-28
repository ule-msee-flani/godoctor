/// A verified pharmacy as patients see it (`chemist_public_profile`).
class PublicChemist {
  const PublicChemist({
    required this.userId,
    required this.name,
    this.avatarPath,
    this.contactPhone,
    this.locationName,
    this.lat,
    this.lng,
    this.memberSince,
    this.medicinesInStock = 0,
    this.ordersFilled = 0,
  });

  final String userId;
  final String name;

  /// Path in the `avatars` bucket (their shop photo).
  final String? avatarPath;
  final String? contactPhone;
  final String? locationName;
  final double? lat;
  final double? lng;
  final DateTime? memberSince;
  final int medicinesInStock;
  final int ordersFilled;

  bool get hasLocation => lat != null && lng != null;

  factory PublicChemist.fromMap(Map<String, dynamic> m) => PublicChemist(
    userId: m['user_id'] as String,
    name: (m['business_name'] as String?)?.trim().isNotEmpty == true
        ? m['business_name'] as String
        : 'Pharmacy',
    avatarPath: m['avatar_url'] as String?,
    contactPhone: m['contact_phone'] as String?,
    locationName: m['location_name'] as String?,
    lat: (m['location_lat'] as num?)?.toDouble(),
    lng: (m['location_lng'] as num?)?.toDouble(),
    memberSince: m['member_since'] == null
        ? null
        : DateTime.tryParse(m['member_since'] as String),
    medicinesInStock: (m['medicines_in_stock'] as num?)?.toInt() ?? 0,
    ordersFilled: (m['orders_filled'] as num?)?.toInt() ?? 0,
  );
}

/// A doctor's track record for their profile (`doctor_public_stats`).
class DoctorPublicStats {
  const DoctorPublicStats({
    this.consultations = 0,
    this.patients = 0,
    this.memberSince,
  });

  final int consultations;
  final int patients;
  final DateTime? memberSince;

  factory DoctorPublicStats.fromMap(Map<String, dynamic>? m) =>
      DoctorPublicStats(
        consultations: (m?['consultations'] as num?)?.toInt() ?? 0,
        patients: (m?['patients'] as num?)?.toInt() ?? 0,
        memberSince: m?['member_since'] == null
            ? null
            : DateTime.tryParse(m!['member_since'] as String),
      );
}
