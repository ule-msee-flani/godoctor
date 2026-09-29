// The big upgrade: floating tab bar, appointment cards and list, mood
// check-in, body map, shop by symptom, pharmacy hours, readings and the
// health card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/utils/format.dart';
import 'package:godoctor_app/core/widgets/floating_nav_bar.dart';
import 'package:godoctor_app/data/models/appointment_item.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/health_reading.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/medicine/shop_by_symptom.dart';
import 'package:godoctor_app/features/patient/appointments/appointments.dart';
import 'package:godoctor_app/features/patient/doctors/inline_booking.dart';
import 'package:godoctor_app/features/patient/health/health_card.dart';
import 'package:godoctor_app/features/patient/health/readings.dart';
import 'package:godoctor_app/features/patient/home/mood_check_in.dart';
import 'package:godoctor_app/features/patient/intake/body_map.dart';
import 'package:godoctor_app/features/patient/screens/patient_home_screen.dart'
    show shortPlace;
import 'package:godoctor_app/services/pharmacy_hours.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime.now();

AppointmentItem _appt(
  String id,
  ConsultationStatus status, {
  Duration from = const Duration(days: 2),
  int? rating,
}) => AppointmentItem(
  id: id,
  doctorId: 'd1',
  doctorName: 'Aden Rosario',
  specialty: 'Orthopedics',
  status: status,
  mode: ConsultationMode.scheduled,
  startsAt: _now.add(from),
  endsAt: _now.add(from).add(const Duration(minutes: 30)),
  facility: 'Mount Adora Hospital',
  myRating: rating,
);

class _Consultations extends ConsultationRepository {
  @override
  Future<List<AppointmentItem>> myAppointments() async => [
    _appt(
      'now',
      ConsultationStatus.scheduled,
      from: const Duration(minutes: 5),
    ),
    _appt('later', ConsultationStatus.scheduled),
    _appt('done', ConsultationStatus.completed, from: const Duration(days: -3)),
    _appt('off', ConsultationStatus.cancelled, from: const Duration(days: -5)),
  ];
}

class _Profiles extends ProfileRepository {
  String? mood;

  @override
  Future<void> logMood(String mood) async => this.mood = mood;

  @override
  Future<List<HealthReading>> readings({String? kind, int limit = 60}) async =>
      kind != 'bp'
      ? const []
      : [
          HealthReading(
            id: 'r2',
            kind: 'bp',
            value: 134,
            value2: 82,
            takenAt: _now.subtract(const Duration(hours: 2)),
          ),
          HealthReading(
            id: 'r1',
            kind: 'bp',
            value: 118,
            value2: 76,
            takenAt: _now.subtract(const Duration(days: 3)),
          ),
        ];

  @override
  Future<({String code, DateTime expiresAt})> createShareCode() async =>
      (code: 'ABCD2345', expiresAt: _now.add(const Duration(minutes: 15)));

  @override
  String? avatarUrl(String? path) => null;
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<List<TimeSlot>> openSlots(
    String doctorId,
    DateTime from,
    DateTime to,
  ) async {
    final day = DateUtils.dateOnly(_now).add(const Duration(days: 1));
    return [
      for (final h in [9, 10, 14])
        TimeSlot(
          start: day.add(Duration(hours: h)),
          end: day.add(Duration(hours: h, minutes: 30)),
        ),
    ];
  }

  @override
  String? avatarUrl(String? path) => null;
}

Drug _drug(String name, {bool rx = false}) => Drug(
  id: name,
  genericName: name,
  brandNames: const [],
  requiresPrescription: rx,
);

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(
  WidgetTester tester,
  Widget child,
  List<Override> overrides, {
  bool scaffold = true,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue('p1'), ...overrides],
      child: MaterialApp(
        theme: AppTheme.patientTheme,
        home: scaffold ? Scaffold(body: child) : child,
      ),
    ),
  );
  await _pump(tester);
}

void main() {
  group('pure helpers', () {
    test('appointments: when, can join, labels, where a tap goes', () {
      final soon = _appt(
        'a',
        ConsultationStatus.scheduled,
        from: const Duration(minutes: 5),
      );
      expect(soon.canJoin(_now), isTrue);
      expect(soon.statusLabel, 'Confirmed');
      expect(soon.route, '/patient/appointment/a');
      expect(soon.doctorLabel, 'Dr. Aden Rosario');
      final later = _appt('b', ConsultationStatus.scheduled);
      expect(later.canJoin(_now), isFalse);
      expect(
        startsIn(_now.add(const Duration(minutes: 40)), now: _now),
        'in 40 min',
      );
      expect(
        startsIn(_now.add(const Duration(minutes: 2)), now: _now),
        'Starting now',
      );
      expect(
        startsIn(
          DateUtils.dateOnly(_now).add(const Duration(days: 4, hours: 9)),
          now: _now,
        ),
        'in 4 days',
      );
      expect(
        _appt('c', ConsultationStatus.completed).route,
        '/patient/visit/c',
      );
      expect(_appt('d', ConsultationStatus.cancelled).isCancelled, isTrue);
    });

    test('body map: areas, suggested specialty, words for the doctor', () {
      expect(specialtyForAreas(['stomach', 'skin']), 'Dermatology');
      expect(specialtyForAreas(['leg_l']), 'Orthopedics');
      expect(specialtyForAreas([]), isNull);
      expect(describeAreas(['arm_l', 'arm_r', 'chest']), 'Arm, Chest');
    });

    test('shop by symptom: over-the-counter medicines on the shelf', () {
      final all = [
        _drug('Paracetamol'),
        _drug('Ibuprofen'),
        _drug('Amoxicillin', rx: true),
        _drug('Omeprazole'),
      ];
      final headache = kSymptomShelves.firstWhere((s) => s.label == 'Headache');
      expect(drugsForShelf(all, headache).map((d) => d.genericName), [
        'Paracetamol',
        'Ibuprofen',
      ]);
      final heartburn = kSymptomShelves.firstWhere(
        (s) => s.label == 'Heartburn',
      );
      expect(drugsForShelf(all, heartburn).single.genericName, 'Omeprazole');
    });

    test('pharmacy hours: open now, overnight, delivery time', () {
      final wed10 = DateTime(2026, 9, 30, 10);
      expect(isOpenNow(const ['Wed'], '08:00-20:00', wed10), isTrue);
      expect(isOpenNow(const ['Mon'], '08:00-20:00', wed10), isFalse);
      expect(
        isOpenNow(const [], '20:00-02:00', DateTime(2026, 9, 30, 23)),
        isTrue,
      );
      expect(isOpenNow(const [], '20:00-02:00', wed10), isFalse);
      expect(isOpenNow(const [], null, wed10), isNull);
      expect(isOpenNow(const ['Wed'], '24 hours', wed10), isTrue);
      expect(deliveryEstimate(2), '~25 min');
      expect(hoursLabel('08:00-20:30'), '8 AM – 8:30 PM');
    });

    test('readings: blood pressure and sugar levels', () {
      HealthReading bp(double s, double d) => HealthReading(
        id: 'x',
        kind: 'bp',
        value: s,
        value2: d,
        takenAt: _now,
      );
      expect(readingLevel(bp(115, 75))!.level, ReadingLevel.normal);
      expect(readingLevel(bp(134, 82))!.label, 'Slightly high');
      expect(readingLevel(bp(150, 95))!.level, ReadingLevel.high);
      expect(readingLevel(bp(185, 100))!.level, ReadingLevel.urgent);
      HealthReading sugar(double v, String c) => HealthReading(
        id: 'y',
        kind: 'sugar',
        value: v,
        context: c,
        takenAt: _now,
      );
      expect(readingLevel(sugar(6.2, 'fasting'))!.label, 'Borderline');
      expect(readingLevel(sugar(6.2, 'after_meal'))!.label, 'Normal');
      expect(readingLevel(sugar(3.2, 'random'))!.label, 'Low');
      expect(bp(128, 84).display, '128/84');
    });

    test('health card codes and small formats', () {
      expect(codeFromQr('GODOCTOR:abcd2345'), 'ABCD2345');
      expect(codeFromQr('ABCD2345'), 'ABCD2345');
      expect(codeFromQr('https://example.com'), isNull);
      expect(cardQrPayload('ABCD2345'), 'GODOCTOR:ABCD2345');
      expect(
        godoctorId('1a2b3c4d-0000-0000-0000-000000000000'),
        'GD-1A2B-3C4D',
      );
      expect(compactCount(950), '950');
      expect(compactCount(2500), '2.5k');
      expect(compactCount(12000), '12k');
      expect(shortPlace('Ruiru, Kiambu, Kenya'), 'Ruiru, Kiambu');
    });
  });

  testWidgets('floating tab bar: the chosen tab shows its name', (
    tester,
  ) async {
    var picked = 0;
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Align(
          alignment: Alignment.bottomCenter,
          child: FloatingNavBar(
            currentIndex: picked,
            onTap: (i) => setState(() => picked = i),
            items: const [
              FloatingNavItem(Icons.home, 'Home'),
              FloatingNavItem(Icons.search, 'Doctors'),
              FloatingNavItem(Icons.chat, 'Chats', badge: 2),
            ],
          ),
        ),
      ),
      const [],
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Doctors'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Doctors'));
    await _pump(tester, 4);
    expect(picked, 1);
    expect(find.text('Doctors'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'the badge');
    expect(tester.takeException(), isNull);
  });

  testWidgets('home: upcoming appointment card with Join when it is time', (
    tester,
  ) async {
    await _host(tester, const UpcomingAppointmentsHero(), [
      consultationRepositoryProvider.overrideWithValue(_Consultations()),
      profileRepositoryProvider.overrideWithValue(_Profiles()),
    ]);
    expect(find.text('Upcoming appointments'), findsOneWidget);
    expect(find.text('Dr. Aden Rosario'), findsOneWidget);
    expect(find.text('Mount Adora Hospital'), findsOneWidget);
    expect(find.text('Join now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('appointments: upcoming, completed, cancelled', (tester) async {
    await _host(tester, const AppointmentsScreen(), [
      consultationRepositoryProvider.overrideWithValue(_Consultations()),
      profileRepositoryProvider.overrideWithValue(_Profiles()),
    ], scaffold: false);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Join now'), findsOneWidget);
    await tester.tap(find.text('Completed'));
    await _pump(tester);
    expect(find.text('Rate this visit'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Cancelled'));
    await _pump(tester);
    expect(find.text('Cancelled'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mood check-in: sad gets a way to talk to someone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final profiles = _Profiles();
    String? unwell;
    await _host(tester, MoodCheckIn(onUnwell: (_, s) => unwell = s), [
      profileRepositoryProvider.overrideWithValue(profiles),
    ]);
    expect(find.text('How do you feel today?'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Sad'));
    await _pump(tester);
    expect(find.text('We\'re here for you.'), findsOneWidget);
    expect(find.text('Talk to someone'), findsOneWidget);
    expect(find.text('Lift your mood'), findsOneWidget);
    expect(profiles.mood, 'sad');

    await tester.tap(find.text('Change'));
    await _pump(tester);
    // The row scrolls sideways to the last feelings.
    await tester.drag(find.byType(ListView).first, const Offset(-300, 0));
    await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Under the weather'));
    await _pump(tester);
    expect(profiles.mood, 'under_the_weather');
    await tester.tap(find.text('Fever'));
    expect(unwell, 'Fever');
    expect(tester.takeException(), isNull);
  });

  testWidgets('body map: tap the figure or a chip', (tester) async {
    var picked = <String>[];
    await _host(
      tester,
      StatefulBuilder(
        builder: (context, setState) => SingleChildScrollView(
          child: BodyMap(
            picked: picked,
            onChanged: (v) => setState(() => picked = v),
          ),
        ),
      ),
      const [],
    );
    final box = tester.getRect(
      find
          .descendant(
            of: find.byType(BodyMap),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    // The chest sits about a quarter of the way down, in the middle.
    await tester.tapAt(Offset(box.center.dx, box.top + box.height * 0.27));
    await tester.pump();
    expect(picked, ['chest']);
    await tester.tap(find.text('Skin'));
    await tester.pump();
    expect(picked, ['chest', 'skin']);
    await tester.tapAt(Offset(box.center.dx, box.top + box.height * 0.27));
    await tester.pump();
    expect(picked, ['skin']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('readings: latest number big, level, trend, list', (
    tester,
  ) async {
    await _host(tester, const ReadingsScreen(initial: 'bp'), [
      profileRepositoryProvider.overrideWithValue(_Profiles()),
    ], scaffold: false);
    expect(find.text('134/82'), findsWidgets);
    expect(find.text('Slightly high'), findsWidgets);
    expect(find.text('Top (systolic)'), findsOneWidget);
    expect(find.byType(ReadingsChart), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('118/76 mmHg'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('118/76 mmHg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('health card: QR with a code that lasts 15 minutes', (
    tester,
  ) async {
    await _host(tester, const HealthCardScreen(), [
      profileRepositoryProvider.overrideWithValue(_Profiles()),
    ], scaffold: false);
    expect(find.text('ABCD 2345'), findsOneWidget);
    expect(find.textContaining('Valid for 1'), findsOneWidget);
    expect(find.textContaining('We\'ll tell you'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('doctor profile: pick a day and a time, then book it', (
    tester,
  ) async {
    await _host(
      tester,
      const SingleChildScrollView(
        child: InlineBooking(
          doctor: PublicDoctor(
            userId: 'd1',
            name: 'Dr Jane',
            specialties: ['General Practice'],
          ),
        ),
      ),
      [doctorDirectoryRepositoryProvider.overrideWithValue(_Directory())],
    );
    expect(find.text('3 free'), findsOneWidget);
    expect(find.text('9:00 AM'), findsOneWidget);
    await tester.tap(find.text('10:00 AM'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Book '), findsOneWidget);
    expect(find.textContaining('10:00 AM'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
