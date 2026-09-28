import 'package:supabase_flutter/supabase_flutter.dart';

/// Turns a backend error into a sentence that is safe and useful to show a
/// patient or doctor. The SQL functions raise short codes (e.g.
/// `slot_unavailable`); anything unrecognised falls back to the server's
/// message rather than a stack trace.
String friendlyError(Object error) {
  final raw = switch (error) {
    PostgrestException e => e.message,
    StorageException e => e.message,
    AuthException e => e.message,
    _ => error.toString(),
  };
  final text = raw.toLowerCase();

  if (text.contains('doctor_unavailable')) {
    return 'That doctor was just taken or went offline. Please choose another doctor.';
  }
  if (text.contains('active_consultation_exists')) {
    return 'You already have a consultation in progress. Finish or cancel it first.';
  }
  if (text.contains('payment_window_expired')) {
    return 'The doctor reservation expired. Please choose a doctor again.';
  }
  if (text.contains('consultation_not_awaiting_payment')) {
    return 'This consultation has already been paid for or was cancelled.';
  }
  if (text.contains('family_member_not_found')) {
    return 'No GoDoctor patient uses that email or phone. Ask them to sign up first, then invite them again.';
  }
  if (text.contains('family_member_is_self')) {
    return 'That is your own account.';
  }
  if (text.contains('family_link_exists')) {
    return 'You are already linked to this person (or an invitation is waiting).';
  }
  if (text.contains('family_limit_reached')) {
    return 'You can invite up to 20 family members.';
  }
  if (text.contains('family_invite_answered')) {
    return 'This invitation was already answered.';
  }
  if (text.contains('not_family')) {
    return 'Only family members who accepted your invitation can join.';
  }
  if (text.contains('family_session_full')) {
    return 'Up to 3 family members can join one consultation.';
  }
  if (text.contains('consultation_not_started')) {
    return 'The consultation has not started yet. You can join once the doctor is on the call.';
  }
  if (text.contains('patients_only')) {
    return 'Only patient accounts can do this.';
  }
  if (text.contains('payment_methods_shape') ||
      text.contains('payment_methods_mpesa_phone_check')) {
    return 'Those payment details are not valid.';
  }
  if (text.contains('consultation_not_active')) {
    return 'More than 24 hours have passed since this consultation, so a prescription can no longer be sent from it.';
  }
  if (text.contains('chat_closed')) {
    return 'This chat closed 24 hours after the consultation. Book another consultation to talk to the doctor again.';
  }
  if (text.contains('prescription_empty')) {
    return 'Add at least one medicine to the prescription.';
  }
  if (text.contains('prescription_too_long')) {
    return 'A prescription can have at most 20 medicines.';
  }
  // Orders (place_order and friends). Some carry the medicine's name after
  // the code, e.g. "out_of_stock: Amoxicillin".
  final named = RegExp(
    r'(out_of_stock|prescription_required|prescription_mismatch): *([^\n]+)',
  ).firstMatch(raw);
  if (named != null) {
    final drug = named.group(2)!.trim();
    return switch (named.group(1)) {
      'out_of_stock' =>
        'The pharmacy no longer has enough $drug. Lower the quantity or choose another pharmacy.',
      'prescription_required' =>
        '$drug needs a prescription. Attach a valid prescription to order it.',
      _ =>
        'The prescription you attached doesn\'t include $drug. Attach the right prescription or remove it.',
    };
  }
  if (text.contains('prescription_expired')) {
    return 'That prescription has expired. Ask a doctor for a new one.';
  }
  if (text.contains('prescription_not_found')) {
    return 'We couldn\'t find that prescription on your account.';
  }
  if (text.contains('chemist_unavailable')) {
    return 'This pharmacy isn\'t taking orders right now. Please choose another.';
  }
  if (text.contains('order_empty')) {
    return 'Add at least one medicine to your order.';
  }
  if (text.contains('order_too_long')) {
    return 'An order can have at most 30 different medicines.';
  }
  if (text.contains('invalid_quantity')) {
    return 'Quantities must be between 1 and 100.';
  }
  if (text.contains('invalid_fulfillment')) {
    return 'Choose pickup or delivery.';
  }
  if (text.contains('order_not_ready')) {
    return 'You can confirm receipt once the pharmacy has confirmed your order.';
  }
  if (text.contains('order_cannot_be_disputed')) {
    return 'This order is already closed. Contact support if something is wrong.';
  }
  if (text.contains('order_status_changed') ||
      text.contains('invalid_status')) {
    return 'This order was already updated. Pull down to refresh.';
  }
  if (text.contains('chemists_only')) {
    return 'Only pharmacy accounts can do this.';
  }
  if (text.contains('import_too_large')) {
    return 'That file is too big. Import up to 2,000 medicines at a time.';
  }
  if (text.contains('too_many_keys')) {
    return 'You can have up to 5 active connection keys. Revoke one first.';
  }
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
      text.contains('clientexception') ||
      text.contains('connection closed') ||
      text.contains('timeoutexception') ||
      text.contains('network is unreachable')) {
    return 'No internet connection. Check your connection and try again.';
  }
  if (text.contains('row-level security') ||
      text.contains('permission denied')) {
    return 'You don\'t have access to this.';
  }
  if (text.contains('jwt expired') || text.contains('invalid jwt')) {
    return 'Your session has expired. Please log in again.';
  }
  // Database / API internals (schema, relationships, SQL errors) mean
  // something is wrong on our side: never show them to people.
  final code = error is PostgrestException ? (error.code ?? '') : '';
  if (code.startsWith('PGRST') ||
      RegExp(r'^[0-9A-Z]{5}$').hasMatch(code) && !_isOurCode(raw) ||
      text.contains('schema cache') ||
      text.contains('relationship') ||
      text.contains('column ') ||
      text.contains('violates') ||
      text.contains('syntax error') ||
      text.contains('function ') ||
      text.contains('exception(')) {
    return 'Something went wrong on our side. Please try again in a moment.';
  }
  return raw.replaceFirst('Exception: ', '');
}

/// Our own SQL functions raise short, readable messages (e.g. "doctor is
/// not yet verified", "chat_closed"); those are fine to pass on.
bool _isOurCode(String message) =>
    message.length < 90 && !message.contains('"') && !message.contains('(');
