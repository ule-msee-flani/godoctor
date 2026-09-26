// The rules behind the after-visit care features: reading a doctor's dose
// into reminders, what the home card shows first, the health story order,
// how late a chemist's ticket is, and the 24-hour chat window.
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_colors.dart';
import 'package:godoctor_app/core/utils/local_touch.dart';
import 'package:godoctor_app/data/models/chat.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/medication.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/features/chat/chats_screen.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_orders_screen.dart';
import 'package:godoctor_app/features/doctor/widgets/visit_summary_editor.dart';
import 'package:godoctor_app/features/patient/health/health_story_screen.dart';
import 'package:godoctor_app/features/patient/home/smart_home_card.dart';
import 'package:godoctor_app/services/data_saver.dart';

final _now = DateTime(2026, 9, 27, 10, 0);

Consultation _c(
  String id, {
  ConsultationStatus status = ConsultationStatus.completed,
  DateTime? at,
  ConsultationMode mode = ConsultationMode.onDemand,
  DateTime? scheduledFor,
  DateTime? scheduledEnd,
}) => Consultation(
  id: id,
  patientId: 'p1',
  doctorId: 'd1',
  specialtyRequested: 'General Practice',
  symptomSummary: 'Headache',
  status: status,
  createdAt: at ?? _now,
  mode: mode,
  scheduledFor: scheduledFor,
  scheduledEnd: scheduledEnd,
);

MedicationSchedule _schedule({List<DoseLog> logs = const []}) =>
    MedicationSchedule(
      id: 's1',
      drugName: 'Amoxicillin',
      dosage: '1 capsule three times daily',
      times: const ['07:00', '14:00', '21:00'],
      startOn: DateTime(2026, 9, 26),
      endOn: DateTime(2026, 9, 30),
      active: true,
      logs: logs,
    );

model.Order _order(String id, OrderStatus status, DateTime at) => model.Order(
  id: id,
  patientId: 'p1',
  chemistId: 'c1',
  status: status,
  totalAmount: 300,
  escrowStatus: EscrowStatus.held,
  fulfillmentType: FulfillmentType.pickup,
  createdAt: at,
);

void main() {
  group('planDoses reads the doctor\'s instructions', () {
    test('three times a day for 5 days', () {
      final p = planDoses(dosage: '1 capsule three times daily for 5 days');
      expect(p.times, ['07:00', '14:00', '21:00']);
      expect(p.days, 5);
    });

    test('twice daily, course length from the quantity', () {
      final p = planDoses(dosage: '2 tablets twice daily', quantity: 20);
      expect(p.times, ['08:00', '20:00']);
      expect(p.days, 5, reason: '20 tablets / (2 a dose x 2 a day)');
    });

    test('at night means one evening reminder', () {
      final p = planDoses(dosage: '2 tablets at night');
      expect(p.times, ['21:00']);
    });

    test('medical shorthand and hours', () {
      expect(planDoses(dosage: '500mg tds').perDay, 3);
      expect(planDoses(dosage: '1 tab every 6 hours').perDay, 4);
      expect(planDoses(instructions: 'bd after meals').perDay, 2);
    });

    test('words that merely contain the shorthand are not misread', () {
      expect(planDoses(dosage: 'apply to abdomen once daily').perDay, 1);
    });

    test('weeks, defaults and limits', () {
      expect(planDoses(dosage: 'once daily for 2 weeks').days, 14);
      expect(planDoses(dosage: 'once daily').days, 5);
      expect(planDoses(dosage: 'once daily for 400 days').days, 90);
    });
  });

  group('a medicine course', () {
    test('day of course, next dose and the pending reminder', () {
      final due = DoseLog(
        id: 'l1',
        dueAt: DateTime(2026, 9, 27, 7),
        status: 'due',
      );
      final s = _schedule(logs: [due]);
      expect(s.totalDays, 5);
      expect(s.dayOfCourse(_now), 2);
      expect(s.nextDose(_now), DateTime(2026, 9, 27, 14));
      expect(s.pendingDose?.id, 'l1');
    });
  });

  group('home card picks the most urgent thing', () {
    final chat = ChatThread(
      consultationId: 'c1',
      otherId: 'd1',
      otherName: 'Dr Jane',
      otherRole: 'doctor',
      specialty: 'General Practice',
      symptoms: 'Headache',
      consultedAt: _now,
      isOpen: true,
      unread: 2,
      closesAt: _now.add(const Duration(hours: 5)),
    );
    final pending = _schedule(
      logs: [DoseLog(id: 'l1', dueAt: DateTime(2026, 9, 27, 7), status: 'due')],
    );

    test('a consultation under way beats everything', () {
      final f = pickHomeFocus(
        now: _now,
        active: _c('a', status: ConsultationStatus.inProgress),
        schedules: [pending],
        chats: [chat],
      );
      expect(f, isA<FocusConsultation>());
    });

    test('then a dose that is due, then an unread reply, then an order', () {
      final order = _order('o1', OrderStatus.confirmed, _now);
      expect(
        pickHomeFocus(
          now: _now,
          schedules: [pending],
          chats: [chat],
          orders: [order],
        ),
        isA<FocusDoseDue>(),
      );
      expect(
        pickHomeFocus(now: _now, chats: [chat], orders: [order]),
        isA<FocusChat>(),
      );
      expect(pickHomeFocus(now: _now, orders: [order]), isA<FocusOrder>());
    });

    test('a dose coming up soon, otherwise "how are you feeling"', () {
      final s = _schedule();
      expect(
        pickHomeFocus(now: DateTime(2026, 9, 27, 12, 30), schedules: [s]),
        isA<FocusNextDose>(),
      );
      expect(
        pickHomeFocus(now: DateTime(2026, 9, 27, 8), schedules: [s]),
        isA<FocusFeeling>(),
        reason: 'next dose is 6 hours away',
      );
      expect(pickHomeFocus(now: _now), isA<FocusFeeling>());
    });

    test('a closed chat does not count', () {
      final closed = ChatThread(
        consultationId: 'c2',
        otherId: 'd1',
        otherName: 'Dr Jane',
        otherRole: 'doctor',
        specialty: 'General Practice',
        symptoms: 'Headache',
        consultedAt: _now,
        isOpen: false,
        unread: 3,
      );
      expect(pickHomeFocus(now: _now, chats: [closed]), isA<FocusFeeling>());
    });
  });

  test('health story: newest first, cancelled requests left out', () {
    final rx = Prescription(
      id: 'rx1',
      patientId: 'p1',
      source: PrescriptionSource.app,
      issuedAt: _now.subtract(const Duration(days: 1)),
      items: const [
        PrescriptionItem(
          prescriptionId: 'rx1',
          drugName: 'Amoxicillin',
          quantity: 15,
        ),
      ],
    );
    final story = buildHealthStory(
      consultations: [
        _c('old', at: _now.subtract(const Duration(days: 3))),
        _c('gone', status: ConsultationStatus.cancelled),
      ],
      prescriptions: [rx],
      orders: [_order('o1', OrderStatus.ready, _now)],
    );
    expect(story.map((e) => e.kind), [
      HealthFilter.orders,
      HealthFilter.prescriptions,
      HealthFilter.consultations,
    ]);
    expect(story.last.route, '/patient/visit/old');
    expect(story.first.status, 'Ready');
    expect(story[1].subtitle, 'Amoxicillin');
  });

  test('chemist tickets turn amber after 10 minutes and red after 20', () {
    DateTime ago(int m) => _now.subtract(Duration(minutes: m));
    expect(
      orderAge(ago(3), OrderStatus.placed, now: _now).color,
      AppColors.success,
    );
    expect(
      orderAge(ago(12), OrderStatus.placed, now: _now).color,
      AppColors.warning,
    );
    expect(
      orderAge(ago(25), OrderStatus.confirmed, now: _now).color,
      AppColors.danger,
    );
    expect(
      orderAge(ago(25), OrderStatus.ready, now: _now).color,
      AppColors.inkSoft,
      reason: 'nothing left to do',
    );
    expect(orderAge(ago(25), OrderStatus.placed, now: _now).label, '25 min');
    expect(laneOf(OrderStatus.refunded), OrderLane.done);
  });

  test('chat window label', () {
    expect(
      chatWindowLabel(
        _now.add(const Duration(hours: 5, minutes: 10)),
        now: _now,
      ),
      'Closes in 5 h',
    );
    expect(
      chatWindowLabel(_now.add(const Duration(minutes: 20)), now: _now),
      'Closes in 20 min',
    );
    expect(
      chatWindowLabel(_now.subtract(const Duration(minutes: 1)), now: _now),
      'Closed',
    );
    expect(chatWindowLabel(null, now: _now), 'Closed');
  });

  test('visit summary draft: chips and own warning signs, saved state', () {
    final d = VisitSummaryDraft();
    expect(d.hasContent, isFalse);
    d.toggleFlag('Severe or worsening pain');
    d.otherFlags.text = 'Stiff neck';
    d.summary.text = 'Rest and fluids.';
    expect(d.redFlagsText, 'Severe or worsening pain\nStiff neck');
    expect(d.dirty, isTrue);
    d.markSaved();
    expect(d.dirty, isFalse);

    final loaded = VisitSummaryDraft()
      ..load(
        Consultation(
          id: 'c',
          patientId: 'p',
          specialtyRequested: 'ENT',
          symptomSummary: 'Ear pain',
          status: ConsultationStatus.completed,
          createdAt: _now,
          summaryForPatient: 'Ear infection.',
          redFlags: 'Severe or worsening pain\nDischarge from the ear',
        ),
      );
    expect(loaded.flags, {'Severe or worsening pain'});
    expect(loaded.otherFlags.text, 'Discharge from the ear');
    expect(loaded.dirty, isFalse);
    d.dispose();
    loaded.dispose();
  });

  test('data estimate for the waiting room', () {
    expect(
      estimateCallData(myVideo: true, theirVideo: true),
      'About 15 MB for 10 minutes',
    );
    expect(
      estimateCallData(myVideo: false, theirVideo: false),
      'About 3 MB for 10 minutes',
    );
  });

  test('a few everyday Swahili words, English otherwise', () {
    LocalTouch.debugSet(swahili: true);
    expect(LocalTouch.greeting(DateTime(2026, 1, 1, 8)), 'Habari za asubuhi');
    expect(LocalTouch.welcome, 'Karibu');
    expect(LocalTouch.thanks, 'Asante!');
    LocalTouch.debugSet(swahili: false);
    expect(LocalTouch.greeting(DateTime(2026, 1, 1, 19)), 'Good evening');
    expect(LocalTouch.welcome, 'Welcome');
  });
}
