import 'enums.dart';

class Prescription {
  const Prescription({
    required this.id,
    this.consultationId,
    required this.patientId,
    this.doctorId,
    required this.source,
    this.imageUrl,
    required this.issuedAt,
    this.validUntil,
    this.items = const [],
  });

  final String id;
  final String? consultationId;
  final String patientId;
  final String? doctorId;
  final PrescriptionSource source;
  final String? imageUrl;
  final DateTime issuedAt;
  final DateTime? validUntil;
  final List<PrescriptionItem> items;

  factory Prescription.fromMap(Map<String, dynamic> map) => Prescription(
    id: map['id'] as String,
    consultationId: map['consultation_id'] as String?,
    patientId: map['patient_id'] as String,
    doctorId: map['doctor_id'] as String?,
    source: enumFromDb(
      PrescriptionSource.values,
      map['source'] as String?,
      PrescriptionSource.app,
    ),
    imageUrl: map['image_url'] as String?,
    issuedAt: DateTime.parse(map['issued_at'] as String),
    validUntil: map['valid_until'] != null
        ? DateTime.tryParse(map['valid_until'] as String)
        : null,
    items:
        (map['prescription_items'] as List<dynamic>?)
            ?.map((e) => PrescriptionItem.fromMap(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );

  bool get isValid => validUntil == null || validUntil!.isAfter(DateTime.now());
}

class PrescriptionItem {
  const PrescriptionItem({
    this.id,
    required this.prescriptionId,
    this.drugId,
    this.freeTextName,
    this.dosage,
    required this.quantity,
    this.instructions,
    this.drugName,
  });

  final String? id;
  final String prescriptionId;
  final String? drugId;
  final String? freeTextName;
  final String? dosage;
  final int quantity;
  final String? instructions;
  // Populated when joined with `drugs` (see PrescriptionRepository queries).
  final String? drugName;

  bool get isStructured => drugId != null;

  /// The best available display name for this item, regardless of whether
  /// it's a structured catalog match or a free-text fallback.
  String get displayName => drugName ?? freeTextName ?? 'Unknown drug';

  factory PrescriptionItem.fromMap(Map<String, dynamic> map) =>
      PrescriptionItem(
        id: map['id'] as String?,
        prescriptionId: map['prescription_id'] as String,
        drugId: map['drug_id'] as String?,
        freeTextName: map['free_text_name'] as String?,
        dosage: map['dosage'] as String?,
        quantity: (map['quantity'] as num?)?.toInt() ?? 1,
        instructions: map['instructions'] as String?,
        drugName:
            (map['drugs'] as Map<String, dynamic>?)?['generic_name'] as String?,
      );

  Map<String, dynamic> toInsertMap() => {
    'prescription_id': prescriptionId,
    'drug_id': drugId,
    'free_text_name': freeTextName,
    'dosage': dosage,
    'quantity': quantity,
    'instructions': instructions,
  };
}
