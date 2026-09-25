import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a backend error into a sentence that is safe and useful to show a
/// patient or doctor. The SQL functions raise short codes (e.g.
/// `slot_unavailable`); anything unrecognised falls back to the server's
/// message rather than a stack trace.
String friendlyError(Object error) {
  final raw = error is PostgrestException ? error.message : error.toString();
  final text = raw.toLowerCase();

  if (text.contains('slot_unavailable')) {
    return 'That time was just taken. Please pick another slot.';
  }
  if (text.contains('too_many_upcoming_appointments')) {
    return 'You already have 10 upcoming appointments. Cancel one to book another.';
  }
  if (text.contains('cannot be started yet')) {
    return 'This appointment cannot be opened yet. You can join 10 minutes before it starts.';
  }
  if (text.contains('cannot be cancelled')) {
    return 'This appointment can no longer be cancelled.';
  }
  if (text.contains('cannot be rescheduled')) {
    return 'This appointment can no longer be rescheduled.';
  }
  if (text.contains('already reviewed')) {
    return 'You have already reviewed this consultation.';
  }
  if (text.contains('only after it is completed')) {
    return 'You can leave a review once the consultation is completed.';
  }
  if (text.contains('failed host lookup') ||
      text.contains('socketexception') ||
      text.contains('clientexception')) {
    return 'No internet connection. Check your connection and try again.';
  }
  return raw.replaceFirst('Exception: ', '');
}
