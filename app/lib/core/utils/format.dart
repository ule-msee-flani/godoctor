import 'package:intl/intl.dart';

/// "KES 1,500", "Free", or "Fee not set".
/// 950 -> "950", 2500 -> "2.5k", 12000 -> "12k".
String compactCount(num n) {
  if (n < 1000) return '${n.round()}';
  final k = n / 1000;
  return k >= 10
      ? '${k.round()}k'
      : '${k.toStringAsFixed(1).replaceAll('.0', '')}k';
}

String formatKes(double? amount) {
  if (amount == null) return 'Fee not set';
  if (amount == 0) return 'Free';
  return 'KES ${NumberFormat('#,##0').format(amount)}';
}

String formatTime(DateTime d) => DateFormat('HH:mm').format(d);

String formatDayShort(DateTime d) => DateFormat('EEE d MMM').format(d);

String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

String formatDateTime(DateTime d) => '${formatDayShort(d)}, ${formatTime(d)}';

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today, 14:30" / "Tomorrow, 09:00" / "Tue 14 Oct, 09:00".
String formatRelativeSlot(DateTime d, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));
  if (isSameDay(d, today)) return 'Today, ${formatTime(d)}';
  if (isSameDay(d, tomorrow)) return 'Tomorrow, ${formatTime(d)}';
  return formatDateTime(d);
}

/// Splits "Dr. Jane Wanjiru" style names into initials ("JW").
String initialsOf(String name) {
  final parts = name
      .replaceAll(RegExp(r'^(dr\.?|prof\.?)\s+', caseSensitive: false), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  return parts.take(2).map((p) => p[0].toUpperCase()).join();
}

/// Human countdown to [target]: "any moment", "in 25 min", "in 3 h 20 min",
/// "in 2 days". Returns "now" if [target] has passed.
String formatCountdown(DateTime target, {DateTime? now}) {
  final diff = target.difference(now ?? DateTime.now());
  if (diff.isNegative) return 'now';
  if (diff.inMinutes < 1) return 'any moment';
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
  if (diff.inHours < 24) {
    final m = diff.inMinutes % 60;
    return m == 0 ? 'in ${diff.inHours} h' : 'in ${diff.inHours} h $m min';
  }
  final days = diff.inDays;
  return 'in $days ${days == 1 ? 'day' : 'days'}';
}
