class Drug {
  const Drug({
    required this.id,
    required this.genericName,
    required this.brandNames,
    this.form,
    required this.requiresPrescription,
    this.category,
    this.imagePath,
    this.chemistPhotoPath,
  });

  final String id;
  final String genericName;
  final List<String> brandNames;
  final String? form;
  final bool requiresPrescription;
  final String? category;

  /// Path in the public `drug-images` storage bucket (optional).
  final String? imagePath;

  /// Most recent pack photo a verified chemist uploaded for this medicine
  /// (path in the public `inventory-photos` bucket), if any.
  final String? chemistPhotoPath;

  Drug withChemistPhoto(String? path) => Drug(
    id: id,
    genericName: genericName,
    brandNames: brandNames,
    form: form,
    requiresPrescription: requiresPrescription,
    category: category,
    imagePath: imagePath,
    chemistPhotoPath: path,
  );

  factory Drug.fromMap(Map<String, dynamic> map) => Drug(
    id: map['id'] as String,
    genericName: (map['generic_name'] as String?) ?? '',
    brandNames: List<String>.from(map['brand_names'] as List? ?? const []),
    form: map['form'] as String?,
    requiresPrescription: (map['requires_prescription'] as bool?) ?? false,
    category: map['category'] as String?,
    imagePath: map['image_path'] as String?,
  );

  String get displayName => brandNames.isNotEmpty
      ? '$genericName (${brandNames.join(', ')})'
      : genericName;
}

class ChemistInventoryItem {
  const ChemistInventoryItem({
    required this.chemistId,
    required this.drugId,
    required this.quantity,
    required this.price,
    required this.lastUpdatedAt,
    this.drug,
    this.chemistName,
    this.chemistLat,
    this.chemistLng,
    this.imagePath,
  });

  final String chemistId;
  final String drugId;
  final int quantity;
  final double price;
  final DateTime lastUpdatedAt;
  // Populated when joined for search results.
  final Drug? drug;
  final String? chemistName;
  final double? chemistLat;
  final double? chemistLng;

  /// Photo of this chemist's pack (path in the `inventory-photos` bucket).
  final String? imagePath;

  factory ChemistInventoryItem.fromMap(Map<String, dynamic> map) {
    final chemistProfile = map['chemist_profiles'] as Map<String, dynamic>?;
    final drugMap = map['drugs'] as Map<String, dynamic>?;
    return ChemistInventoryItem(
      chemistId: map['chemist_id'] as String,
      drugId: map['drug_id'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0,
      lastUpdatedAt: DateTime.parse(map['last_updated_at'] as String),
      drug: drugMap != null ? Drug.fromMap(drugMap) : null,
      chemistName: chemistProfile?['business_name'] as String?,
      chemistLat: (chemistProfile?['location_lat'] as num?)?.toDouble(),
      chemistLng: (chemistProfile?['location_lng'] as num?)?.toDouble(),
      imagePath: map['image_path'] as String?,
    );
  }
}
