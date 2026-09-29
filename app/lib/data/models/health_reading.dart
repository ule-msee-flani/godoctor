/// A number the patient logged: blood pressure, blood sugar or weight.
class HealthReading {
  const HealthReading({
    required this.id,
    required this.kind,
    required this.value,
    this.value2,
    this.context,
    required this.takenAt,
    this.note,
  });

  final String id;

  /// 'bp', 'sugar' or 'weight'.
  final String kind;

  /// Systolic (bp), mmol/L (sugar) or kg (weight).
  final double value;

  /// Diastolic (bp).
  final double? value2;

  /// Sugar: 'fasting', 'after_meal' or 'random'.
  final String? context;
  final DateTime takenAt;
  final String? note;

  factory HealthReading.fromMap(Map<String, dynamic> m) => HealthReading(
    id: m['id'] as String,
    kind: m['kind'] as String,
    value: (m['value'] as num).toDouble(),
    value2: (m['value2'] as num?)?.toDouble(),
    context: m['context'] as String?,
    takenAt: DateTime.parse(m['taken_at'] as String).toLocal(),
    note: m['note'] as String?,
  );

  /// "128/84", "5.4", "72.5".
  String get display => switch (kind) {
    'bp' => '${value.round()}/${value2?.round() ?? '–'}',
    'weight' => value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
    _ => value.toStringAsFixed(1),
  };

  String get unit => switch (kind) {
    'bp' => 'mmHg',
    'sugar' => 'mmol/L',
    _ => 'kg',
  };
}

enum ReadingLevel { low, normal, borderline, high, urgent }

/// Where a reading sits, with a plain label. Weight has no level. General
/// adult guidance; the screen says to ask a doctor.
({ReadingLevel level, String label})? readingLevel(HealthReading r) {
  switch (r.kind) {
    case 'bp':
      final s = r.value, d = r.value2 ?? 0;
      if (s >= 180 || d >= 120) {
        return (level: ReadingLevel.urgent, label: 'Very high: get help now');
      }
      if (s >= 140 || d >= 90) {
        return (level: ReadingLevel.high, label: 'High');
      }
      if (s >= 130 || d >= 80) {
        return (level: ReadingLevel.borderline, label: 'Slightly high');
      }
      if (s < 90 || d < 60) return (level: ReadingLevel.low, label: 'Low');
      return (level: ReadingLevel.normal, label: 'Normal');
    case 'sugar':
      final v = r.value;
      if (v < 3.9) return (level: ReadingLevel.low, label: 'Low');
      final fasting = r.context == 'fasting';
      if (v >= (fasting ? 7.0 : 11.1)) {
        return (level: ReadingLevel.high, label: 'High');
      }
      if (v >= (fasting ? 5.6 : 7.8)) {
        return (level: ReadingLevel.borderline, label: 'Borderline');
      }
      return (level: ReadingLevel.normal, label: 'Normal');
    default:
      return null;
  }
}
