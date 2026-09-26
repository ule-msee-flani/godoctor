// Tapping a notification (in the inbox or as a push) opens the screen it is
// about, for each kind of user.
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/services/notification_routes.dart';

String? go(String kind, UserRole role, [Map<String, dynamic> data = const {}]) =>
    routeForNotification(kind: kind, data: data, role: role);

void main() {
  const c = {'consultation_id': 'c1'};

  test('patient', () {
    const p = UserRole.patient;
    expect(
      go('prescription_issued', p, {'prescription_id': 'rx1'}),
      '/patient/prescription/rx1/order',
    );
    expect(go('payment_window_ending', p, c), '/patient/consult/c1/pay');
    expect(go('doctor_ready', p, c), '/patient/appointment/c1');
    expect(go('family_session_invite', p, c), '/patient/family-session/c1');
    expect(go('family_invite', p), '/patient/profile/family');
    expect(go('order_ready', p, {'order_id': 'o1'}), '/patient/order/o1');
    expect(go('payment_receipt', p, {'order_id': 'o1'}), '/patient/order/o1');
    expect(go('payment_receipt', p, c), '/patient/profile/billing');
    expect(go('consultation_completed', p, c), '/patient/waiting/c1');
    expect(
      go('consultation_completed', p, {...c, 'mode': 'scheduled'}),
      '/patient/appointment/c1',
    );
    expect(go('announcement', p), isNull, reason: 'stays in the inbox');
  });

  test('doctor', () {
    const d = UserRole.doctor;
    expect(go('patient_paid', d, c), '/doctor/call/c1');
    expect(go('patient_waiting', d, c), '/doctor/call/c1');
    expect(go('patient_selected', d, c), '/doctor');
    expect(go('review_new', d, c), '/doctor/history');
    expect(go('verification_approved', d), '/doctor/profile');
  });

  test('chemist', () {
    const ch = UserRole.chemist;
    expect(go('order_new', ch, {'order_id': 'o1'}), '/chemist');
    expect(go('verification_approved', ch), '/chemist/account');
  });

  test('admin', () {
    const a = UserRole.admin;
    expect(go('verification_submitted', a), '/admin/verification');
    expect(go('support_new', a, {'ticket_id': 't1'}), '/admin/support/t1');
    expect(go('order_disputed', a, {'order_id': 'o1'}), '/admin/orders');
    expect(go('emergency_flagged', a, c), '/admin/consultations');
  });

  test('support replies open the conversation for everyone', () {
    for (final role in UserRole.values) {
      expect(
        go('support_reply', role, {'ticket_id': 't9'}),
        '/account/support/t9',
      );
    }
  });

  test('a patient-only link is not offered to a doctor', () {
    expect(go('family_invite', UserRole.doctor), isNull);
    expect(
      go('prescription_issued', UserRole.chemist, {'prescription_id': 'x'}),
      isNull,
    );
  });
}
