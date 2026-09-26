import '../data/models/enums.dart';

/// Where tapping a notification takes each kind of user. Shared by the
/// in-app inbox and by push notifications, so both always agree.
///
/// Returns null when there is nowhere more specific than the inbox.
String? routeForNotification({
  required String kind,
  required Map<String, dynamic> data,
  required UserRole? role,
}) {
  String? id(String key) {
    final v = data[key];
    return v == null || '$v'.isEmpty ? null : '$v';
  }

  final consultation = id('consultation_id');
  final order = id('order_id');
  final ticket = id('ticket_id');
  final prescription = id('prescription_id');

  // Support replies look the same for everyone.
  if (kind == 'support_reply' && ticket != null) {
    return '/account/support/$ticket';
  }

  switch (role) {
    case UserRole.patient:
      return switch (kind) {
        'prescription_issued' when prescription != null =>
          '/patient/prescription/$prescription/order',
        'payment_window_ending' when consultation != null =>
          '/patient/consult/$consultation/pay',
        'family_session_invite' when consultation != null =>
          '/patient/family-session/$consultation',
        'family_joined' when consultation != null =>
          '/patient/call/$consultation',
        'family_invite' || 'family_accepted' => '/patient/profile/family',
        'doctor_ready' when consultation != null =>
          '/patient/appointment/$consultation',
        'appointment_booked' ||
        'appointment_cancelled' ||
        'appointment_rescheduled' ||
        'appointment_reminder' when consultation != null =>
          '/patient/appointment/$consultation',
        'consultation_completed' when consultation != null =>
          '/patient/visit/$consultation',
        'chat_message' when consultation != null =>
          '/patient/chat/$consultation',
        'dose_due' => '/patient/health',
        'request_expired' ||
        'consultation_cancelled' => '/patient/consultation-history',
        'order_confirmed' ||
        'order_ready' ||
        'order_refunded' when order != null => '/patient/order/$order',
        'payment_receipt' =>
          order != null ? '/patient/order/$order' : '/patient/profile/billing',
        _ => null,
      };

    case UserRole.doctor:
      return switch (kind) {
        'patient_paid' || 'patient_waiting' || 'family_joined'
            when consultation != null =>
          '/doctor/call/$consultation',
        'patient_selected' ||
        'patient_cancelled' ||
        'request_expired' ||
        'consultation_cancelled' ||
        'appointment_booked' ||
        'appointment_cancelled' ||
        'appointment_rescheduled' ||
        'appointment_reminder' => '/doctor',
        'chat_message' when consultation != null =>
          '/doctor/chat/$consultation',
        'review_new' => '/doctor/history',
        'verification_approved' || 'verification_removed' => '/doctor/profile',
        _ => null,
      };

    case UserRole.chemist:
      return switch (kind) {
        'order_new' ||
        'order_completed' ||
        'order_disputed' ||
        'order_refunded' => '/chemist',
        'verification_approved' || 'verification_removed' => '/chemist/account',
        _ => null,
      };

    case UserRole.admin:
      return switch (kind) {
        'verification_submitted' => '/admin/verification',
        'support_new' ||
        'support_user_reply' when ticket != null => '/admin/support/$ticket',
        'order_disputed' => '/admin/orders',
        'emergency_flagged' => '/admin/consultations',
        _ => null,
      };

    case null:
      return null;
  }
}
