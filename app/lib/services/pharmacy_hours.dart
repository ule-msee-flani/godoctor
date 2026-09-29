import 'package:intl/intl.dart';

/// Whether a pharmacy is open at [now], from what it told us: the days it
/// opens ("Mon".."Sun"; none means every day) and its hours ("24 hours" or
/// "08:00-20:00"). Null when it hasn't said.
bool? isOpenNow(List<String> days, String? hours, DateTime now) {
  if ((hours == null || hours.isEmpty) && days.isEmpty) return null;
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final today = names[now.weekday - 1];
  if (days.isNotEmpty && !days.contains(today)) return false;
  if (hours == null || hours.isEmpty || hours == '24 hours') return true;
  final m = RegExp(r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$').firstMatch(hours);
  if (m == null) return null;
  int at(int h, int mm) => h * 60 + mm;
  final open = at(int.parse(m.group(1)!), int.parse(m.group(2)!));
  final close = at(int.parse(m.group(3)!), int.parse(m.group(4)!));
  final t = at(now.hour, now.minute);
  // Past midnight, e.g. 20:00-02:00.
  return close > open ? t >= open && t < close : t >= open || t < close;
}

/// A rough delivery time for [km] away: "~25 min".
String deliveryEstimate(double km) {
  final mins = (15 + km * 5).round();
  final rounded = ((mins + 4) ~/ 5) * 5;
  return rounded >= 90 ? '~1.5 h+' : '~$rounded min';
}

/// "08:00-20:00" -> "8 AM – 8 PM".
String hoursLabel(String? hours) {
  if (hours == null || hours.isEmpty) return 'Hours not added';
  if (hours == '24 hours') return 'Open 24 hours';
  final m = RegExp(r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$').firstMatch(hours);
  if (m == null) return hours;
  String t(String h, String mm) {
    final d = DateTime(2000, 1, 1, int.parse(h), int.parse(mm));
    return DateFormat(mm == '00' ? 'h a' : 'h:mm a').format(d);
  }

  return '${t(m.group(1)!, m.group(2)!)} – ${t(m.group(3)!, m.group(4)!)}';
}
