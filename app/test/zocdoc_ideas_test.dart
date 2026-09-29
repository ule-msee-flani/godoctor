// Ideas borrowed from Zocdoc: open slots per day on doctor cards, "My
// doctors", a fuller rating breakdown, the Well guide, plus the smaller
// per-phone update download.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/my_doctor.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/appointment_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/patient/doctors/my_doctors.dart';
import 'package:godoctor_app/features/patient/health/well_guide.dart';
import 'package:godoctor_app/features/patient/widgets/doctor_widgets.dart';
import 'package:godoctor_app/features/patient/widgets/review_sheet.dart';
import 'package:godoctor_app/features/reviews/review_widgets.dart';
import 'package:godoctor_app/services/app_update.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

const _jane = PublicDoctor(
  userId: 'd1',
  name: 'Dr Jane Wanjiru',
  specialties: ['General Practice'],
  consultationFee: 800,
  ratingAvg: 4.6,
  ratingCount: 12,
);

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<List<MyDoctor>> myDoctors() async => [
    MyDoctor(
      doctor: _jane,
      visits: 2,
      lastVisit: _now.subtract(const Duration(days: 20)),
      favorite: true,
    ),
    const MyDoctor(
      doctor: PublicDoctor(
        userId: 'd2',
        name: 'Dr Otieno',
        specialties: ['Paediatrics'],
        availableNow: true,
      ),
    ),
  ];

  @override
  String? avatarUrl(String? path) => null;
}

class _Profiles extends ProfileRepository {
  final saved = <String, DateTime>{'bp': DateTime(2020, 1, 10)};

  @override
  Future<Map<String, DateTime>> preventiveChecks() async => {...saved};

  @override
  String? avatarUrl(String? path) => null;
}

class _Appointments extends AppointmentRepository {
  ({int rating, String? comment, int? onTime, int? manner})? sent;

  @override
  Future<void> submitReview({
    required String consultationId,
    required int rating,
    String? comment,
    int? onTime,
    int? manner,
  }) async {
    sent = (rating: rating, comment: comment, onTime: onTime, manner: manner);
  }
}

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _host(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue('p1'), ...overrides],
      child: MaterialApp(
        theme: AppTheme.patientTheme,
        home: Scaffold(body: child),
      ),
    ),
  );
  await _pump(tester);
}

void main() {
  group('well guide', () {
    final now = DateTime(2026, 9, 29);

    test('fits the patient: age and gender decide the checks', () {
      final woman = wellGuideFor(age: 30, gender: 'female', now: now);
      final keys = woman.map((i) => i.check.key).toSet();
      expect(keys, containsAll(['bp', 'hiv', 'cervical', 'dental']));
      expect(keys, isNot(contains('prostate')));
      expect(keys, isNot(contains('sugar')), reason: 'from 35');

      final man = wellGuideFor(age: 55, gender: 'male', now: now);
      expect(
        man.map((i) => i.check.key),
        containsAll(['prostate', 'sugar', 'cholesterol', 'eyes']),
      );
      expect(man.map((i) => i.check.key), isNot(contains('cervical')));
    });

    test('unknown age or gender: only checks for everyone', () {
      final keys = wellGuideFor(now: now).map((i) => i.check.key).toSet();
      expect(keys, containsAll(['bp', 'weight', 'hiv', 'dental']));
      expect(keys, isNot(contains('cervical')));
      expect(keys, isNot(contains('sugar')));
    });

    test('status: overdue, due soon, up to date, never; due first', () {
      final items = wellGuideFor(
        age: 40,
        gender: 'male',
        now: now,
        done: {
          'bp': DateTime(2025, 3, 1), // due Mar 2026: overdue
          'hiv': DateTime(2025, 10, 20), // due Oct 2026: soon
          'dental': DateTime(2026, 6, 1), // due Jun 2027: fine
        },
      );
      WellItem of(String k) => items.firstWhere((i) => i.check.key == k);
      expect(of('bp').status, WellStatus.overdue);
      expect(of('hiv').status, WellStatus.dueSoon);
      expect(of('hiv').done, isTrue);
      expect(of('dental').status, WellStatus.upToDate);
      expect(of('dental').dueBy, DateTime(2027, 6, 1));
      expect(of('weight').status, WellStatus.never);
      expect(items.first.status, WellStatus.overdue);
      expect(items.last.status, WellStatus.upToDate);
    });

    test('age on a date', () {
      expect(ageOn(DateTime(1990, 10, 1), now), 35);
      expect(ageOn(DateTime(1990, 9, 29), now), 36);
      expect(ageOn(null, now), isNull);
    });
  });

  group('smaller updates', () {
    const body = '''
{"version":"1.7.0","build":9,
 "apk":"https://example.com/GoDoctor-1.7.0.apk","size":20000000,
 "apks":{"arm64-v8a":{"url":"https://example.com/GoDoctor-1.7.0.apk","size":20000000},
         "armeabi-v7a":{"url":"https://example.com/GoDoctor-1.7.0-32bit.apk","size":18000000}},
 "notes":["Faster"]}''';

    test('each phone downloads its own APK', () {
      expect(
        AppRelease.tryParse(body, abi: 'armeabi-v7a')!.apkUrl,
        endsWith('-32bit.apk'),
      );
      final arm64 = AppRelease.tryParse(body, abi: 'arm64-v8a')!;
      expect(arm64.apkUrl, endsWith('1.7.0.apk'));
      expect(arm64.sizeLabel, '19 MB');
      // Unknown type (or an old version.json): the main APK.
      expect(
        AppRelease.tryParse(body, abi: 'x86_64')!.apkUrl,
        endsWith('1.7.0.apk'),
      );
    });

    test('per-phone versionCodes compare by release number', () {
      final r = AppRelease.tryParse(body, abi: 'arm64-v8a');
      expect(releaseNumber(2008), 8);
      expect(releaseNumber(1008), 8);
      expect(releaseNumber(7), 7);
      expect(isNewerRelease(r, releaseNumber(2008)), isTrue);
      expect(isNewerRelease(r, releaseNumber(2009)), isFalse);
      expect(isNewerRelease(r, releaseNumber(7)), isTrue, reason: 'from 1.6.0');
    });
  });

  test('rating breakdown: every review counted, sub-scores', () {
    final b = RatingBreakdown.fromJson({
      'average': 4.2,
      'count': 5,
      'on_time': 4.5,
      'manner': null,
      'stars': {'5': 3, '4': 0, '3': 1, '2': 0, '1': 1},
    });
    expect(b.share(5), 0.6);
    expect(b.share(1), 0.2);
    expect(b.onTime, 4.5);
    expect(b.manner, isNull);
  });

  testWidgets('doctor card: open slots day by day', (tester) async {
    await _host(
      tester,
      DoctorCard(
        doctor: _jane,
        slots: {_today: 3, _today.add(const Duration(days: 2)): 1},
      ),
      [doctorDirectoryRepositoryProvider.overrideWithValue(_Directory())],
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3 slots'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('None'), findsNWidgets(2));
    expect(find.text('1 slot'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('my doctors: saved first, book again or see now', (tester) async {
    await _host(
      tester,
      const Padding(padding: EdgeInsets.all(16), child: MyDoctorsRow()),
      [doctorDirectoryRepositoryProvider.overrideWithValue(_Directory())],
    );
    expect(find.text('My doctors'), findsOneWidget);
    expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
    expect(find.textContaining('Seen 2 times'), findsOneWidget);
    expect(find.text('Book again'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('See now'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile ratings: overall, per star, on time, manner', (
    tester,
  ) async {
    await _host(
      tester,
      SingleChildScrollView(
        child: ReviewsBlock(
          reviews: AsyncData([
            DoctorReview(
              id: 'r1',
              rating: 5,
              comment: 'Listened well · On time',
              createdAt: _now,
            ),
          ]),
          average: 4.2,
          count: 5,
          emptyText: 'none',
          breakdown: const RatingBreakdown(
            average: 4.2,
            count: 5,
            onTime: 4.8,
            manner: 4.4,
            stars: {5: 3, 3: 1, 1: 1},
          ),
        ),
      ),
      const [],
    );
    expect(find.text('4.2'), findsOneWidget);
    expect(find.text('On time'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('Bedside manner'), findsOneWidget);
    expect(find.text('4.4'), findsOneWidget);
    expect(find.text('Listened well · On time'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rating a doctor can include on time and bedside manner', (
    tester,
  ) async {
    final appointments = _Appointments();
    await _host(
      tester,
      Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () => showReviewSheet(
              context,
              consultationId: 'c1',
              doctorName: 'Dr Jane Wanjiru',
              initialRating: 5,
            ),
            child: const Text('rate'),
          ),
        ),
      ),
      [appointmentRepositoryProvider.overrideWithValue(appointments)],
    );
    await tester.tap(find.text('rate'));
    await _pump(tester);
    expect(find.text('Excellent'), findsOneWidget);
    await tester.tap(find.byTooltip('On time 4'));
    await tester.tap(find.byTooltip('Bedside manner 5'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit review'));
    await tester.tap(find.text('Submit review'));
    await _pump(tester);
    expect(appointments.sent?.rating, 5);
    expect(appointments.sent?.onTime, 4);
    expect(appointments.sent?.manner, 5);
  });

  testWidgets('well guide screen: progress, to do and done', (tester) async {
    await _host(tester, const WellGuideScreen(), [
      profileRepositoryProvider.overrideWithValue(_Profiles()),
      currentPatientProfileProvider.overrideWith(
        (ref) async => PatientProfile(
          userId: 'p1',
          name: 'Amina',
          gender: 'female',
          dateOfBirth: DateTime(_now.year - 30, 1, 1),
        ),
      ),
    ]);
    expect(find.text('Your progress'), findsOneWidget);
    expect(find.text('Blood pressure check'), findsOneWidget);
    expect(find.textContaining('Due since'), findsOneWidget, reason: 'bp 2020');
    await tester.scrollUntilVisible(
      find.text('Cervical cancer screening'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Prostate check'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('Done ('),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.textContaining('Done ('));
    await _pump(tester, 4);
    expect(
      find.textContaining('Mark check-ups as done'),
      findsOneWidget,
      reason: 'nothing is up to date yet',
    );
    expect(tester.takeException(), isNull);
  });
}
