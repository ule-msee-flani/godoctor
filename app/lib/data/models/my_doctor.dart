import 'public_doctor.dart';

/// A doctor in "My doctors": one the patient has seen, or saved.
class MyDoctor {
  const MyDoctor({
    required this.doctor,
    this.visits = 0,
    this.lastVisit,
    this.favorite = false,
  });

  final PublicDoctor doctor;
  final int visits;
  final DateTime? lastVisit;
  final bool favorite;

  factory MyDoctor.fromMap(Map<String, dynamic> m) => MyDoctor(
    doctor: PublicDoctor.fromMap(m),
    visits: (m['visits'] as num?)?.toInt() ?? 0,
    lastVisit: m['last_visit'] == null
        ? null
        : DateTime.tryParse(m['last_visit'] as String)?.toLocal(),
    favorite: (m['favorite'] as bool?) ?? false,
  );
}

/// The full picture of someone's ratings (`rating_breakdown()`).
class RatingBreakdown {
  const RatingBreakdown({
    this.average = 0,
    this.count = 0,
    this.onTime,
    this.manner,
    this.stars = const {},
  });

  final double average;
  final int count;

  /// Average "on time" stars (doctors), when patients gave them.
  final double? onTime;

  /// Average "bedside manner" stars (doctors).
  final double? manner;

  /// How many reviews gave each number of stars (1-5).
  final Map<int, int> stars;

  /// Share of reviews with [star] stars (0-1).
  double share(int star) => count == 0 ? 0 : (stars[star] ?? 0) / count;

  factory RatingBreakdown.fromJson(Map<String, dynamic> j) => RatingBreakdown(
    average: (j['average'] as num?)?.toDouble() ?? 0,
    count: (j['count'] as num?)?.toInt() ?? 0,
    onTime: (j['on_time'] as num?)?.toDouble(),
    manner: (j['manner'] as num?)?.toDouble(),
    stars: {
      for (final e in ((j['stars'] as Map?) ?? const {}).entries)
        int.parse('${e.key}'): (e.value as num).toInt(),
    },
  );
}
