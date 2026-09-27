// The patient's side of the new consultation experience: the waiting room
// and the "doctor joined" moment, the 24-hour chat, the visit summary and
// the Health tab's story.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/video_call_panel.dart';
import 'package:godoctor_app/data/models/chat.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/medication.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/chat_repository.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/medication_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/prescription_repository.dart';
import 'package:godoctor_app/features/chat/chat_screen.dart';
import 'package:godoctor_app/features/chat/chats_screen.dart';
import 'package:godoctor_app/features/patient/health/health_story_screen.dart';
import 'package:godoctor_app/features/patient/screens/patient_call_screen.dart';
import 'package:godoctor_app/features/patient/visit/visit_summary_screen.dart';

import 'support/fakes.dart';

final _now = DateTime.now();

Consultation _consultation({
  ConsultationStatus status = ConsultationStatus.completed,
  DateTime? doctorJoinedAt,
  DateTime? chatClosesAt,
  bool doctorVideo = true,
}) => Consultation(
  id: 'c1',
  patientId: 'p1',
  doctorId: 'd1',
  specialtyRequested: 'General Practice',
  symptomSummary: 'Headache and fever since Monday',
  status: status,
  createdAt: _now.subtract(const Duration(hours: 2)),
  startedAt: _now.subtract(const Duration(hours: 2)),
  doctorVideoPreferred: doctorVideo,
  doctorJoinedAt: doctorJoinedAt,
  summaryForPatient: 'Most likely a viral infection. Rest and drink fluids.',
  redFlags: 'Difficulty breathing or chest pain',
  followUpOn: _now.add(const Duration(days: 7)),
  chatClosesAt: chatClosesAt,
);

final _rx = Prescription(
  id: 'rx1',
  consultationId: 'c1',
  patientId: 'p1',
  doctorId: 'd1',
  source: PrescriptionSource.app,
  issuedAt: _now.subtract(const Duration(hours: 1)),
  validUntil: _now.add(const Duration(days: 30)),
  items: const [
    PrescriptionItem(
      id: 'i1',
      prescriptionId: 'rx1',
      drugId: 'para',
      drugName: 'Paracetamol',
      dosage: '2 tablets three times daily',
      quantity: 18,
    ),
  ],
);

ChatThread _thread({bool open = true, int unread = 1}) => ChatThread(
  consultationId: 'c1',
  otherId: 'd1',
  otherName: 'Dr Jane Wanjiru',
  otherRole: 'doctor',
  specialty: 'General Practice',
  symptoms: 'Headache and fever since Monday',
  consultedAt: _now.subtract(const Duration(hours: 2)),
  closesAt: open
      ? _now.add(const Duration(hours: 22))
      : _now.subtract(const Duration(hours: 1)),
  isOpen: open,
  unread: unread,
  lastBody: 'How are you feeling today?',
  lastAt: _now.subtract(const Duration(minutes: 5)),
);

class _Consultations extends ConsultationRepository {
  _Consultations(this.stream);

  final Stream<Consultation?> stream;

  @override
  Stream<Consultation?> watchConsultation(String consultationId) => stream;
  @override
  Future<List<Consultation>> fetchHistoryForPatient(String patientId) async => [
    _consultation(),
  ];
}

class _Prescriptions extends PrescriptionRepository {
  _Prescriptions({this.list});

  final List<Prescription>? list;

  @override
  Stream<List<Prescription>> watchForConsultation(String consultationId) =>
      Stream.value(list ?? [_rx]);
  @override
  Future<List<Prescription>> fetchForPatient(String patientId) async =>
      list ?? [_rx];
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<PublicDoctor?> getDoctor(String doctorId) async => const PublicDoctor(
    userId: 'd1',
    name: 'Dr Jane Wanjiru',
    specialties: ['General Practice'],
  );
}

class _Chats extends ChatRepository {
  _Chats({this.open = true});

  final bool open;
  final sent = <String>[];

  @override
  Future<List<ChatThread>> myChats() async => [_thread(open: open)];
  @override
  Stream<List<ChatMessage>> watchMessages(String consultationId) =>
      Stream.value([
        ChatMessage(
          id: 'm1',
          consultationId: 'c1',
          body: 'Dr Jane Wanjiru sent a new prescription.',
          isSystem: true,
          createdAt: _now.subtract(const Duration(minutes: 30)),
        ),
        ChatMessage(
          id: 'm2',
          consultationId: 'c1',
          senderId: 'd1',
          body: 'How are you feeling today?',
          createdAt: _now.subtract(const Duration(minutes: 5)),
        ),
      ]);
  @override
  Stream<void> watchAny() => const Stream.empty();
  @override
  Future<void> send(String consultationId, String body) async => sent.add(body);
  @override
  Future<void> markRead(String consultationId) async {}
}

class _Orders extends OrderRepository {
  @override
  Future<List<model.Order>> fetchForPatient(String patientId) async => [
    model.Order(
      id: 'o1',
      patientId: 'p1',
      chemistId: 'ch1',
      status: OrderStatus.ready,
      totalAmount: 360,
      escrowStatus: EscrowStatus.held,
      fulfillmentType: FulfillmentType.pickup,
      createdAt: _now.subtract(const Duration(minutes: 40)),
      chemistName: 'Afya Chemist',
    ),
  ];
}

class _Medications extends MedicationRepository {
  @override
  Future<List<MedicationSchedule>> mySchedules({
    bool activeOnly = false,
  }) async {
    final today = DateTime(_now.year, _now.month, _now.day);
    return [
      MedicationSchedule(
        id: 's1',
        drugName: 'Paracetamol',
        dosage: '2 tablets three times daily',
        times: const ['07:00', '14:00', '21:00'],
        startOn: today.subtract(const Duration(days: 1)),
        endOn: today.add(const Duration(days: 2)),
        active: true,
        prescriptionItemId: 'i1',
      ),
    ];
  }
}

Future<void> _render(
  WidgetTester tester,
  Widget screen, {
  Stream<Consultation?>? consultation,
  _Chats? chats,
  List<Prescription>? prescriptions,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('p1'),
        currentPatientProfileProvider.overrideWith(
          (ref) async => const PatientProfile(
            userId: 'p1',
            name: 'Amina Hassan',
            allergies: 'Penicillin',
            bloodGroup: 'O+',
          ),
        ),
        consultationRepositoryProvider.overrideWithValue(
          _Consultations(consultation ?? Stream.value(_consultation())),
        ),
        prescriptionRepositoryProvider.overrideWithValue(
          _Prescriptions(list: prescriptions),
        ),
        doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
        chatRepositoryProvider.overrideWithValue(chats ?? _Chats()),
        orderRepositoryProvider.overrideWithValue(_Orders()),
        medicationRepositoryProvider.overrideWithValue(_Medications()),
        familyRepositoryProvider.overrideWithValue(FakeFamily()),
      ],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('waiting room until the doctor joins, then the call', (
    tester,
  ) async {
    final live = StreamController<Consultation?>();
    addTearDown(live.close);
    await _render(
      tester,
      const PatientCallScreen(consultationId: 'c1'),
      consultation: live.stream,
      prescriptions: const [],
    );
    live.add(
      _consultation(status: ConsultationStatus.inProgress, doctorVideo: false),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Waiting room'), findsOneWidget);
    expect(
      find.text('Dr Jane Wanjiru will be with you shortly'),
      findsOneWidget,
    );
    expect(find.text('Your camera'), findsOneWidget);
    expect(find.textContaining('camera stays off'), findsOneWidget);
    expect(find.byType(VideoCallPanel), findsNothing);

    // The doctor opens the call.
    live.add(
      _consultation(
        status: ConsultationStatus.inProgress,
        doctorVideo: false,
        doctorJoinedAt: _now,
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Dr Jane Wanjiru joined'), findsOneWidget);
    expect(find.byType(VideoCallPanel), findsOneWidget);
    expect(find.text('Camera off'), findsOneWidget, reason: 'as asked');
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('after the call: summary and a free chat are offered', (
    tester,
  ) async {
    await _render(
      tester,
      const PatientCallScreen(consultationId: 'c1'),
      consultation: Stream.value(
        _consultation(chatClosesAt: _now.add(const Duration(hours: 23))),
      ),
    );
    expect(find.text('See your visit summary'), findsOneWidget);
    expect(find.textContaining('free for 24 h'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Remind me to take these'), 300);
    expect(find.text('Remind me to take these'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('chats list shows open chats with unread count', (tester) async {
    await _render(tester, const ChatsScreen(doctor: false));
    expect(find.text('Open now'), findsOneWidget);
    expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
    expect(find.text('How are you feeling today?'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Closes in'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('chat: context pinned on top, quick reply sends', (tester) async {
    final chats = _Chats();
    await _render(
      tester,
      const ChatScreen(consultationId: 'c1', doctor: false),
      chats: chats,
      consultation: Stream.value(
        _consultation(chatClosesAt: _now.add(const Duration(hours: 20))),
      ),
    );
    expect(find.textContaining('From your video consultation'), findsOneWidget);
    expect(find.text('Prescribed: Paracetamol'), findsOneWidget);
    expect(
      find.text('Dr Jane Wanjiru sent a new prescription.'),
      findsOneWidget,
    );

    await tester.tap(find.text('The chemist doesn\'t have this medicine'));
    await tester.pump();
    expect(chats.sent, ['The chemist doesn\'t have this medicine']);

    // Expand the pinned card: medicines with their dose, and the summary.
    await tester.tap(find.textContaining('From your video consultation'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('Paracetamol · 2 tablets three times daily · Qty 18'),
      findsOneWidget,
    );
    expect(find.text('Doctor\'s summary'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('a closed chat can be read but not written in', (tester) async {
    await _render(
      tester,
      const ChatScreen(consultationId: 'c1', doctor: false),
      chats: _Chats(open: false),
      consultation: Stream.value(
        _consultation(chatClosesAt: _now.subtract(const Duration(hours: 1))),
      ),
    );
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Book another consultation'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('visit summary card', (tester) async {
    await _render(
      tester,
      const VisitSummaryScreen(consultationId: 'c1'),
      consultation: Stream.value(
        _consultation(chatClosesAt: _now.add(const Duration(hours: 20))),
      ),
    );
    expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
    expect(find.textContaining('viral infection'), findsOneWidget);
    expect(find.text('Paracetamol'), findsOneWidget);
    expect(find.text('Difficulty breathing or chest pain'), findsOneWidget);
    expect(find.text('Share (WhatsApp, SMS...)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Book the follow-up'), 200);
    expect(find.text('Remind me to take my medicines'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('reminder sheet reads the dose into times', (tester) async {
    await _render(
      tester,
      const VisitSummaryScreen(consultationId: 'c1'),
      consultation: Stream.value(_consultation()),
    );
    await tester.scrollUntilVisible(
      find.text('Remind me to take my medicines'),
      200,
    );
    await tester.tap(find.text('Remind me to take my medicines'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Dose reminders'), findsOneWidget);
    // Already has a reminder (from the fake schedule for item i1).
    expect(find.text('Reminder on'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('health story: facts, medicines, one timeline', (tester) async {
    await _render(tester, const HealthStoryScreen());
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
    expect(find.text('Medicines you\'re taking'), findsOneWidget);
    expect(find.text('Your health story'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('General Practice consultation'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Medicine order'), findsOneWidget);
    expect(find.textContaining('Prescription · 1 medicine'), findsOneWidget);

    await tester.ensureVisible(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pump();
    expect(find.text('General Practice consultation'), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}
