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
        this.ratingAvg = 0,
    this.ratingCount = 0,
    this.offersDelivery,
    this.deliveryRadiusKm,
    this.openingHours,
    this.openDays = const [],
    this.services = const [],
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

  /// Average of every patient's rating (0 when there are none).
  final double ratingAvg;
    final int ratingCount;

  /// Null when they haven't said.
  final bool? offersDelivery;
  final int? deliveryRadiusKm;

  /// "24 hours" or "08:00-20:00".
  final String? openingHours;

  /// "Mon".."Sun"; empty when not given.
  final List<String> openDays;
  final List<String> services;

  /// They deliver to a place [km] away.
  bool deliversTo(double? km) =>
      offersDelivery == true &&
      (km == null || deliveryRadiusKm == null || km <= deliveryRadiusKm!);

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
    ratingAvg: (m['rating_avg'] as num?)?.toDouble() ?? 0,
        ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
    offersDelivery: m['offers_delivery'] as bool?,
    deliveryRadiusKm: (m['delivery_radius_km'] as num?)?.toInt(),
    openingHours: m['opening_hours'] as String?,
    openDays: ((m['open_days'] as List?) ?? const []).cast<String>(),
    services: ((m['services'] as List?) ?? const []).cast<String>(),
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
