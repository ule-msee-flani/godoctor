/// A medicine reminder schedule (created from a prescription line).
class MedicationSchedule {
  const MedicationSchedule({
    required this.id,
    required this.drugName,
    required this.times,
    required this.startOn,
    required this.endOn,
    required this.active,
    this.dosage,
    this.prescriptionItemId,
    this.logs = const [],
  });

  final String id;
  final String drugName;
  final String? dosage;

  /// 'HH:MM' in Nairobi time.
  final List<String> times;
  final DateTime startOn;
  final DateTime endOn;
  final bool active;
  final String? prescriptionItemId;
  final List<DoseLog> logs;

  int get totalDays => endOn.difference(startOn).inDays + 1;

  /// 1-based day of the course today (clamped).
  int dayOfCourse(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return (today.difference(startOn).inDays + 1).clamp(1, totalDays);
  }

  int get takenCount => logs.where((l) => l.status == 'taken').length;

  /// Doses taken out of doses that have come due so far.
  double adherence(DateTime now) {
    final due = logs.where((l) => l.dueAt.isBefore(now)).length;
    return due == 0 ? 1 : takenCount / due;
  }

  /// A reminder that was sent and not yet answered (taken/skipped).
  DoseLog? get pendingDose {
    final pending = logs.where((l) => l.status == 'due').toList()
      ..sort((a, b) => b.dueAt.compareTo(a.dueAt));
    return pending.isEmpty ? null : pending.first;
  }

  /// The next reminder time today or later, or null when the course is over.
  DateTime? nextDose(DateTime now) {
    for (var d = 0; d <= totalDays; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      if (day.isAfter(endOn)) break;
      if (day.isBefore(startOn)) continue;
      final sorted = [...times]..sort();
      for (final t in sorted) {
        final parts = t.split(':');
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (at.isAfter(now)) return at;
      }
    }
    return null;
  }

  factory MedicationSchedule.fromMap(Map<String, dynamic> m) =>
      MedicationSchedule(
        id: m['id'] as String,
        drugName: (m['drug_name'] as String?) ?? '',
        dosage: m['dosage'] as String?,
        times: ((m['times'] as List?) ?? const []).cast<String>(),
        startOn: DateTime.parse(m['start_on'] as String),
        endOn: DateTime.parse(m['end_on'] as String),
        active: (m['active'] as bool?) ?? true,
        prescriptionItemId: m['prescription_item_id'] as String?,
        logs: ((m['dose_logs'] as List?) ?? const [])
            .map((l) => DoseLog.fromMap(l as Map<String, dynamic>))
            .toList(),
      );
}

class DoseLog {
  const DoseLog({
    required this.id,
    required this.dueAt,
    required this.status,
    this.takenAt,
  });

  final String id;
  final DateTime dueAt;

  /// due | taken | skipped
  final String status;
  final DateTime? takenAt;

  factory DoseLog.fromMap(Map<String, dynamic> m) => DoseLog(
    id: m['id'] as String,
    dueAt: DateTime.parse(m['due_at'] as String).toLocal(),
    status: (m['status'] as String?) ?? 'due',
    takenAt: m['taken_at'] == null
        ? null
        : DateTime.parse(m['taken_at'] as String).toLocal(),
  );
}

/// What a dose instruction like "1 tablet twice daily for 5 days" means.
class DosePlan {
  const DosePlan({required this.times, required this.days});

  /// Reminder times, 'HH:MM'.
  final List<String> times;
  final int days;

  int get perDay => times.length;
}

/// How many doses a day the doctor's text says, or null if it doesn't say
/// ("once/twice/three/four times daily", "every 8 hours", tds, bd...).
int? dosesPerDayIn(String? dosage, [String? instructions]) {
  final text = '${dosage ?? ''} ${instructions ?? ''}'.toLowerCase();
  if (RegExp(r'four times|4 times|\bqid\b|every 6 ?h').hasMatch(text)) {
    return 4;
  }
  if (RegExp(
    r'three times|3 times|thrice|\btds\b|\btid\b|every 8 ?h',
  ).hasMatch(text)) {
    return 3;
  }
  if (RegExp(
    r'twice|two times|2 times|\bbd\b|\bbid\b|every 12 ?h',
  ).hasMatch(text)) {
    return 2;
  }
  if (RegExp(
    r'once|one time|1 time|\bod\b|daily|a day|at night|bedtime|every 24 ?h',
  ).hasMatch(text)) {
    return 1;
  }
  return null;
}

/// How many days the course lasts: "for 5 days" / "x 7 days" / "for 2
/// weeks", else worked out from the quantity. Null if it can't be told.
int? courseDaysIn({
  String? dosage,
  String? instructions,
  int? quantity,
  int? perDay,
}) {
  final text = '${dosage ?? ''} ${instructions ?? ''}'.toLowerCase();
  final dm = RegExp(r'(\d+)\s*(day|days|d)\b').firstMatch(text);
  final wm = RegExp(r'(\d+)\s*(week|weeks)\b').firstMatch(text);
  if (dm != null) return int.parse(dm.group(1)!).clamp(1, 90);
  if (wm != null) return (int.parse(wm.group(1)!) * 7).clamp(1, 90);
  if (quantity != null && quantity > 1 && perDay != null) {
    final perDose =
        int.tryParse(
          RegExp(r'^\s*(\d+)').firstMatch(dosage ?? '')?.group(1) ?? '',
        ) ??
        1;
    return (quantity / (perDay * perDose)).ceil().clamp(1, 90);
  }
  return null;
}

/// Reads a doctor's dose text (+ quantity) into reminder times and course
/// length. Understands the phrasing used by the prescribing sheet
/// ("once/twice/three times daily", "every 8 hours", "at night", "for 5
/// days"); falls back to once a day for 5 days. Pure, so it's easy to test.
DosePlan planDoses({String? dosage, String? instructions, int? quantity}) {
  final text = '${dosage ?? ''} ${instructions ?? ''}'.toLowerCase();
  final perDay = dosesPerDayIn(dosage, instructions) ?? 1;

  final times = switch (perDay) {
    4 => ['07:00', '12:00', '17:00', '22:00'],
    3 => ['07:00', '14:00', '21:00'],
    2 => ['08:00', '20:00'],
    _ => [RegExp(r'night|bedtime|evening').hasMatch(text) ? '21:00' : '08:00'],
  };

  final days =
      courseDaysIn(
        dosage: dosage,
        instructions: instructions,
        quantity: quantity,
        perDay: perDay,
      ) ??
      5;
  return DosePlan(times: times, days: days);
}
