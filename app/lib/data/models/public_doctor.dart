/// A doctor as shown to patients in the directory. Built from the
/// `search_doctors` / `get_public_doctor` SQL functions, which expose only
/// safe columns (never licence numbers or verification documents) and only
/// for licence-verified doctors.
class PublicDoctor {
  const PublicDoctor({
    required this.userId,
    required this.name,
    required this.specialties,
    this.bio,
    this.consultationFee,
    this.languages = const [],
    this.gender,
    this.yearsExperience,
    this.avatarPath,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.availableNow = false,
    this.nextSlot,
  });

  final String userId;
  final String name;
  final List<String> specialties;
  final String? bio;
  final double? consultationFee;
  final List<String> languages;
  final String? gender;
  final int? yearsExperience;

  /// Path inside the public `avatars` storage bucket.
  final String? avatarPath;
  final double ratingAvg;
  final int ratingCount;
  final bool availableNow;
  final DateTime? nextSlot;

  String get primarySpecialty =>
      specialties.isNotEmpty ? specialties.first : 'General Practice';

  factory PublicDoctor.fromMap(Map<String, dynamic> map) => PublicDoctor(
    userId: map['user_id'] as String,
    name: (map['name'] as String?) ?? '',
    specialties: ((map['specialties'] as List?) ?? const []).cast<String>(),
    bio: map['bio'] as String?,
    consultationFee: (map['consultation_fee'] as num?)?.toDouble(),
    languages: ((map['languages'] as List?) ?? const []).cast<String>(),
    gender: map['gender'] as String?,
    yearsExperience: (map['years_experience'] as num?)?.toInt(),
    avatarPath: map['avatar_url'] as String?,
    ratingAvg: (map['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
    availableNow: (map['available_now'] as bool?) ?? false,
    nextSlot: map['next_slot'] != null
        ? DateTime.tryParse(map['next_slot'] as String)?.toLocal()
        : null,
  );
}

/// One bookable time window.
class TimeSlot {
  const TimeSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory TimeSlot.fromMap(Map<String, dynamic> map) => TimeSlot(
    start: DateTime.parse(map['slot_start'] as String).toLocal(),
    end: DateTime.parse(map['slot_end'] as String).toLocal(),
  );
}

/// An anonymous public review (author identity is never exposed).
class DoctorReview {
  const DoctorReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory DoctorReview.fromMap(Map<String, dynamic> map) => DoctorReview(
    id: map['id'] as String,
    rating: (map['rating'] as num).toInt(),
    comment: map['comment'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
  );
}

/// A doctor's weekly availability window (ISO weekday: 1=Mon .. 7=Sun).
class AvailabilityWindow {
  const AvailabilityWindow({
    this.id,
    required this.weekday,
    required this.start,
    required this.end,
    this.slotMinutes = 30,
  });

  final String? id;
  final int weekday;

  /// "HH:mm" 24-hour, as Postgres `time` renders it (seconds trimmed).
  final String start;
  final String end;
  final int slotMinutes;

  factory AvailabilityWindow.fromMap(Map<String, dynamic> map) =>
      AvailabilityWindow(
        id: map['id'] as String?,
        weekday: (map['weekday'] as num).toInt(),
        start: _hhmm(map['start_time'] as String),
        end: _hhmm(map['end_time'] as String),
        slotMinutes: (map['slot_minutes'] as num?)?.toInt() ?? 30,
      );

  static String _hhmm(String t) => t.length >= 5 ? t.substring(0, 5) : t;
}

class TimeOff {
  const TimeOff({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    this.reason,
  });

  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? reason;

  factory TimeOff.fromMap(Map<String, dynamic> map) => TimeOff(
    id: map['id'] as String,
    startsAt: DateTime.parse(map['starts_at'] as String).toLocal(),
    endsAt: DateTime.parse(map['ends_at'] as String).toLocal(),
    reason: map['reason'] as String?,
  );
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    this.body,
    this.consultationId,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? consultationId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory AppNotificationItem.fromMap(Map<String, dynamic> map) =>
      AppNotificationItem(
        id: map['id'] as String,
        kind: (map['kind'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        body: map['body'] as String?,
        consultationId:
            (map['data'] as Map<String, dynamic>?)?['consultation_id']
                as String?,
        readAt: map['read_at'] != null
            ? DateTime.tryParse(map['read_at'] as String)?.toLocal()
            : null,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}

/// Languages a doctor can list (and patients can filter by). Stored verbatim
/// in doctor_profiles.languages, so keep these labels stable.
const kDoctorLanguages = [
  'English',
  'Swahili',
  'Kikuyu',
  'Luo',
  'Kalenjin',
  'Luhya',
  'Kamba',
  'Somali',
  'French',
  'Arabic',
];
