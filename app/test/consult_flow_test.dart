// Renders the three "See a doctor" steps with fake data, at phone and desktop
// size, and fails on any rendering error.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/features/patient/consult/available_doctors_screen.dart';
import 'package:godoctor_app/features/patient/consult/consult_flow.dart';
import 'package:godoctor_app/features/patient/consult/consult_pay_screen.dart';
import 'package:godoctor_app/features/patient/screens/doctor_profile_screen.dart';
import 'package:godoctor_app/features/patient/screens/intake_form_screen.dart';

import 'support/fakes.dart';

final _now = DateTime.now();

const _doctor = PublicDoctor(
  userId: 'd1',
  name: 'Dr Jane Wanjiru',
  specialties: ['ENT'],
  bio: 'ENT specialist.',
  consultationFee: 800,
  languages: ['English', 'Swahili'],
  yearsExperience: 9,
  ratingAvg: 4.7,
  ratingCount: 21,
  availableNow: true,
);

class _Directory extends DoctorDirectoryRepository {
  _Directory({this.empty = false});
  final bool empty;

  @override
  Future<List<PublicDoctor>> search({
    String? query,
    String? specialty,
    double? maxFee,
    String? language,
    String? gender,
    bool availableNow = false,
    int limit = 20,
    int offset = 0,
  }) async => empty ? [] : [_doctor];

  @override
  Future<PublicDoctor?> getDoctor(String doctorId) async => _doctor;

  @override
  Future<List<DoctorReview>> reviews(
    String doctorId, {
    int limit = 20,
    int offset = 0,
  }) async => [
    DoctorReview(
      id: 'r1',
      rating: 5,
      comment: 'Very clear and kind.',
      createdAt: _now,
    ),
  ];

  @override
  String? avatarUrl(String? path) => null;
}

class _Consultations extends ConsultationRepository {
  _Consultations(this.status);
  final ConsultationStatus status;

  @override
  Stream<Consultation?> watchConsultation(String consultationId) =>
      Stream.value(
        Consultation(
          id: consultationId,
          patientId: 'p1',
          doctorId: 'd1',
          specialtyRequested: 'ENT',
          symptomSummary: 'Ear pain for 3 days',
          status: status,
          createdAt: _now,
          feeAmount: 800,
          paymentDueAt: _now.add(const Duration(minutes: 9)),
        ),
      );
}

Future<void> _render(
  WidgetTester tester,
  Widget screen, {
  required Size size,
  bool withDraft = true,
  bool noDoctors = false,
  ConsultationStatus status = ConsultationStatus.awaitingPayment,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('p1'),
        consultDraftProvider.overrideWith(
          (ref) => withDraft
              ? const ConsultDraft(
                  specialty: 'ENT',
                  symptoms: 'Ear pain for 3 days',
                )
              : null,
        ),
        doctorDirectoryRepositoryProvider.overrideWithValue(
          _Directory(empty: noDoctors),
        ),
        consultationRepositoryProvider.overrideWithValue(
          _Consultations(status),
        ),
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
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  for (final (label, size) in [
    ('phone', const Size(412, 915)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets('step 1: category + description ($label)', (tester) async {
      await _render(
        tester,
        const IntakeFormScreen(),
        size: size,
        withDraft: false,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Choose a category first'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('step 2: online doctors list ($label)', (tester) async {
      await _render(tester, const AvailableDoctorsScreen(), size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('step 2: nobody online ($label)', (tester) async {
      await _render(
        tester,
        const AvailableDoctorsScreen(),
        size: size,
        noDoctors: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('See a General doctor instead'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('step 2: doctor profile with "See now" ($label)', (
      tester,
    ) async {
      await _render(
        tester,
        const DoctorProfileScreen(doctorId: 'd1', seeNow: true),
        size: size,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('See Dr Jane now'), findsOneWidget);
      expect(find.text('Book appointment'), findsNothing);
      await _close(tester);
    });

    testWidgets('step 3: pay screen ($label)', (tester) async {
      await _render(
        tester,
        const ConsultPayScreen(consultationId: 'c1'),
        size: size,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Pay KES 800 with M-Pesa'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('step 3: expired/cancelled request ($label)', (tester) async {
      await _render(
        tester,
        const ConsultPayScreen(consultationId: 'c1'),
        size: size,
        status: ConsultationStatus.cancelled,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Choose a doctor'), findsOneWidget);
      await _close(tester);
    });
  }

  testWidgets('step 1 continues only with a category and a description', (
    tester,
  ) async {
    await _render(
      tester,
      const IntakeFormScreen(),
      size: const Size(412, 915),
      withDraft: false,
    );
    await tester.ensureVisible(find.text('ENT').first);
    await tester.tap(find.text('ENT').first);
    await tester.pump();
    expect(find.text('Find a doctor'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Find a doctor'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNull, reason: 'no description yet');
    await tester.enterText(find.byType(TextField), 'Ear pain for three days');
    await tester.pump();
    final enabled = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Find a doctor'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(enabled.onPressed, isNotNull);
    await _close(tester);
  });
}
