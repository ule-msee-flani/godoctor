// The welcome path after sign-up, the "details are genuine" declaration on
// registration, and the awaiting-verification screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/pending_verification_view.dart';
import 'package:godoctor_app/data/models/app_user.dart';
import 'package:godoctor_app/data/models/doctor_profile.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_onboarding_screen.dart';
import 'package:godoctor_app/features/onboarding/path_inputs.dart';
import 'package:godoctor_app/features/onboarding/path_steps.dart';
import 'package:godoctor_app/features/onboarding/welcome_path_screen.dart';

class _Profiles extends ProfileRepository {
  Map<String, Object?>? saved;

  @override
  Future<void> completeOnboarding(Map<String, Object?> answers) async {
    saved = answers;
  }
}

AppUser _user(UserRole role) => AppUser(
  id: 'u1',
  role: role,
  status: UserStatus.active,
  createdAt: DateTime(2026),
);

const _doctor = DoctorProfile(
  userId: 'u1',
  name: 'Dr Jane Wanjiru',
  specialties: ['General Practice'],
  licenseVerified: false,
  verificationDocuments: [],
  status: DoctorStatus.offline,
  ratingAvg: 0,
  consultationFee: 800,
  languages: ['English'],
);

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Continue (or Skip), then wait for the walk to the next question.
Future<void> _go(WidgetTester tester, String button) async {
  await tester.tap(find.text(button));
  await _pump(tester, 18);
}

Future<void> _host(
  WidgetTester tester,
  Widget screen,
  List<Override> overrides,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currentUserIdProvider.overrideWithValue('u1'), ...overrides],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await _pump(tester);
}

void main() {
  group('answers', () {
    test('chips and "other" text round-trip through one line', () {
      final r = splitChoices('Asthma, diabetes, Gout', const [
        'Asthma',
        'Diabetes',
      ], noneLabel: 'None');
      expect(r.picked, {'Asthma', 'Diabetes', 'other'});
      expect(r.other, 'Gout');
      expect(joinChoices(r.picked, r.other), 'Asthma, Diabetes, Gout');
      expect(joinChoices({'none'}, ''), 'None');
      expect(splitChoices('None', const [], noneLabel: 'None').picked, {
        'none',
      });
    });

    test('what goes to the server', () {
      final out = answersForServer({
        'name': 'Amina',
        'date_of_birth': DateTime(1995, 4, 2),
        'languages': {'English', 'Kiswahili'},
        '_conditions_set': {'none'},
        '_allergies_set': {'Penicillin', 'other'},
        '_allergies_other': 'Latex gloves',
        '_meds_yes': false,
        '_photo': 'bytes',
        'gender': null,
      });
      expect(out['name'], 'Amina');
      expect(out['date_of_birth'], '1995-04-02');
      expect(out['languages'], containsAll(['English', 'Kiswahili']));
      expect(out['conditions'], 'None');
      expect(out['allergies'], 'Penicillin, Latex gloves');
      expect(out['medications'], '');
      expect(out.containsKey('_photo'), isFalse);
      expect(out.containsKey('gender'), isFalse);
    });

    test('county from a place, and warmer words near the end', () {
      expect(countyFromPlace('Ruiru, Kiambu, Kenya'), 'Kiambu');
      expect(countyFromPlace('Kilimani, Nairobi County, Kenya'), 'Nairobi');
      expect(countyFromPlace('Somewhere'), isNull);
      expect(encouragement(9, 10), 'Last one!');
      expect(encouragement(8, 10), 'Almost there.');
    });
  });

  testWidgets('patient: one question at a time, skip, finish', (tester) async {
    final profiles = _Profiles();
    await _host(tester, const WelcomePathScreen(), [
      profileRepositoryProvider.overrideWithValue(profiles),
      currentAppUserProvider.overrideWith(
        (ref) async => _user(UserRole.patient),
      ),
      currentPatientProfileProvider.overrideWith(
        (ref) async => const PatientProfile(userId: 'u1', name: 'Amina Hassan'),
      ),
    ]);

    expect(
      find.text('Welcome to GoDoctor! What\'s your name?'),
      findsOneWidget,
    );
    // Nothing but the question: no step counter or app bar.
    expect(find.byType(AppBar), findsNothing);
    expect(find.textContaining('of 10'), findsNothing);
    expect(find.text('Skip for now'), findsNothing, reason: 'name is needed');

    await _go(tester, 'Continue');
    expect(find.text('When were you born?'), findsOneWidget);

    // Back goes to the previous question.
    await tester.binding.handlePopRoute();
    await _pump(tester);
    expect(
      find.text('Welcome to GoDoctor! What\'s your name?'),
      findsOneWidget,
    );
    await _go(tester, 'Continue');

    await _go(tester, 'Skip for now'); // born
    await _go(tester, 'Skip for now'); // where
    expect(
      find.text('Do you live with any long-term conditions?'),
      findsOneWidget,
    );
    await tester.tap(find.text('None'));
    await tester.pump();
    await _go(tester, 'Continue');
    for (var i = 0; i < 5; i++) {
      await _go(tester, 'Skip for now'); // allergies .. cover
    }
    expect(find.text('How did you hear about GoDoctor?'), findsOneWidget);
    await tester.tap(find.text('Social media'));
    await tester.pump();
    await tester.tap(find.text('Finish'));
    await _pump(tester, 20);

    expect(find.text('You\'re all set, Amina!'), findsOneWidget);
    expect(find.textContaining('Enjoy GoDoctor.'), findsOneWidget);
    expect(profiles.saved?['name'], 'Amina Hassan');
    expect(profiles.saved?['conditions'], 'None');
    expect(profiles.saved?['heard_from'], 'Social media');
    expect(profiles.saved?.containsKey('date_of_birth'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor: go on and save lives, then verify the licence', (
    tester,
  ) async {
    final profiles = _Profiles();
    await _host(tester, const WelcomePathScreen(), [
      profileRepositoryProvider.overrideWithValue(profiles),
      currentAppUserProvider.overrideWith(
        (ref) async => _user(UserRole.doctor),
      ),
      currentDoctorProfileProvider.overrideWith((ref) async => _doctor),
    ]);
    expect(
      find.text('Welcome, Doctor. What name should patients see?'),
      findsOneWidget,
    );
    await _go(tester, 'Continue'); // name (known)
    await _go(tester, 'Continue'); // speciality (known)
    expect(find.text('How many years have you practised?'), findsOneWidget);
    await _go(tester, 'Continue');
    await _go(tester, 'Continue'); // languages (English)
    await _go(tester, 'Skip for now'); // where
    await _go(tester, 'Skip for now'); // focus
    expect(find.text('KES 800'), findsOneWidget);
    await _go(tester, 'Continue'); // fee (known)
    await _go(tester, 'Skip for now'); // times
    await tester.tap(find.text('Finish'));
    await _pump(tester, 20);

    expect(find.text('Go on and save lives.'), findsOneWidget);
    expect(find.text('Verify my licence'), findsOneWidget);
    expect(profiles.saved?['specialties'], ['General Practice']);
    expect(profiles.saved?['consultation_fee'], 800);
    expect(profiles.saved?['years_experience'], 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('doctor registration: confirm the details are genuine first', (
    tester,
  ) async {
    await _host(tester, const DoctorOnboardingScreen(), [
      currentDoctorProfileProvider.overrideWith((ref) async => _doctor),
    ]);
    // Filled in from the welcome path.
    expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'A12345');
    final submit = find.widgetWithText(FilledButton, 'Submit for verification');
    await tester.scrollUntilVisible(
      submit,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await _pump(tester);
    expect(find.text('Submit for verification?'), findsOneWidget);
    expect(find.textContaining('KMPDC register'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await _pump(tester);
    expect(find.text('Submit for verification?'), findsNothing);
  });

  testWidgets('awaiting verification: where it stands and what comes next', (
    tester,
  ) async {
    await _host(
      tester,
      const PendingVerificationView(
        title: 'Awaiting verification',
        description: 'Our team checks your licence.',
      ),
      const [],
    );
    expect(find.text('Awaiting verification'), findsOneWidget);
    expect(find.text('Registration submitted'), findsOneWidget);
    expect(find.text('We\'re checking your licence'), findsOneWidget);
    expect(find.textContaining('few working days'), findsOneWidget);
    expect(find.textContaining('email you'), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
