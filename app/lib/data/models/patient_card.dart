/// What a doctor or pharmacy may see about their own patient
/// (`patient_card()`): enough to treat or dispense safely, no contact
/// details.
class PatientCard {
  const PatientCard({
    required this.userId,
    required this.name,
    this.avatarPath,
    this.age,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.conditions,
    this.medications,
    this.memberSince,
    this.visitsWithMe = 0,
    this.ordersWithMe = 0,
  });

  final String userId;
  final String name;

  /// Path in the `avatars` bucket.
  final String? avatarPath;
  final int? age;
  final String? gender;
  final String? bloodGroup;
  final String? allergies;
  final String? conditions;
  final String? medications;
  final DateTime? memberSince;
  final int visitsWithMe;
  final int ordersWithMe;

  String get displayName => name.trim().isEmpty ? 'GoDoctor patient' : name;

  bool get hasAllergies => _has(allergies) && !_none(allergies!);

  /// "34 yrs · Female".
  String get basics => [
    if (age != null) '$age yrs',
    if (gender != null && gender!.isNotEmpty)
      gender![0].toUpperCase() + gender!.substring(1),
  ].join(' · ');

  static bool _has(String? s) => (s ?? '').trim().isNotEmpty;

  static bool _none(String s) => RegExp(
    r'^(none|no|nil|n/?a|nkda|no known.*)$',
    caseSensitive: false,
  ).hasMatch(s.trim());

  /// Splits "Penicillin, peanuts; latex" into separate items.
  static List<String> items(String? s) => [
    for (final p in (s ?? '').split(RegExp(r'[,;\n]')))
      if (p.trim().isNotEmpty && !_none(p)) p.trim(),
  ];

  factory PatientCard.fromMap(Map<String, dynamic> m) => PatientCard(
    userId: m['user_id'] as String,
    name: (m['name'] as String?) ?? '',
    avatarPath: m['avatar_url'] as String?,
    age: (m['age'] as num?)?.toInt(),
    gender: m['gender'] as String?,
    bloodGroup: m['blood_group'] as String?,
    allergies: m['allergies'] as String?,
    conditions: m['chronic_conditions'] as String?,
    medications: m['current_medications'] as String?,
    memberSince: m['member_since'] == null
        ? null
        : DateTime.tryParse(m['member_since'] as String),
    visitsWithMe: (m['visits_with_me'] as num?)?.toInt() ?? 0,
    ordersWithMe: (m['orders_with_me'] as num?)?.toInt() ?? 0,
  );
}
