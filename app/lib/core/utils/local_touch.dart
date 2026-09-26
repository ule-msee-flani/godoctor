import 'dart:math' as math;

/// A light Kenyan touch: a few everyday Swahili words that everyone knows
/// (Karibu, Habari, Asante, Pole) sometimes stand in for the English. The
/// app stays in English; the choice is made once per app launch so the text
/// doesn't flicker while you use it.
class LocalTouch {
  LocalTouch._();

  /// About one launch in three uses the Swahili words.
  static bool swahili = math.Random().nextInt(3) == 0;

  /// For tests.
  static void debugSet({required bool swahili}) => LocalTouch.swahili = swahili;

  static String _pick(String sw, String en) => swahili ? sw : en;

  /// "Habari za asubuhi" / "Good morning" (and afternoon, evening).
  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return _pick('Habari za asubuhi', 'Good morning');
    if (h < 17) return _pick('Habari za mchana', 'Good afternoon');
    return _pick('Habari za jioni', 'Good evening');
  }

  /// "Karibu" / "Welcome".
  static String get welcome => _pick('Karibu', 'Welcome');

  /// "Asante!" / "Thank you!"
  static String get thanks => _pick('Asante!', 'Thank you!');

  /// "Pole," / "Sorry," (sympathy, e.g. a cancelled request).
  static String get sorry => _pick('Pole,', 'Sorry,');

  /// "Pona haraka" / "Get well soon".
  static String get getWell => _pick('Pona haraka', 'Get well soon');
}
