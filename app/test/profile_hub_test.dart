// The patient Profile hub and everything under it: user profile, health
// details, location (map picker), family + family sessions, billing, and
// support & feedback. Renders each at phone and desktop size and checks
// the key interactions against in-memory fakes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/app_user.dart';
import 'package:godoctor_app/data/models/billing.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/family.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/support.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/location/location_picker_screen.dart';
import 'package:godoctor_app/features/patient/family/family_session_screen.dart';
import 'package:godoctor_app/features/patient/profile/account_screen.dart';
import 'package:godoctor_app/features/patient/profile/billing_screen.dart';
import 'package:godoctor_app/features/patient/profile/family_screen.dart';
import 'package:godoctor_app/features/patient/profile/health_screen.dart';
import 'package:godoctor_app/features/patient/profile/location_screen.dart';
import 'package:godoctor_app/features/patient/screens/profile_screen.dart';
import 'package:godoctor_app/features/support/new_ticket_screen.dart';
import 'package:godoctor_app/features/support/support_screen.dart';
import 'package:godoctor_app/features/support/ticket_screen.dart';
import 'package:godoctor_app/services/geocoding.dart';

import 'support/fakes.dart';

const _profile = PatientProfile(
  userId: 'p1',
  name: 'Amina Hassan',
  locationLat: -1.1466,
  locationLng: 36.9609,
  locationName: 'Ruiru, Kiambu, Kenya',
  allergies: 'Penicillin',
  bloodGroup: 'O+',
);

class _Profiles extends ProfileRepository {
  PatientProfile? saved;

  @override
  Future<void> updatePatientProfile(PatientProfile profile) async =>
      saved = profile;
  @override
  Future<void> updateContactPhone(String userId, String? phone) async {}
  @override
  String? avatarUrl(String? path) => null;
  @override
  Future<void> touchPresence() async {}
}

class _Consultations extends ConsultationRepository {
  @override
  Future<List<Consultation>> fetchHistoryForPatient(String patientId) async =>
      const [];
}

class _Orders extends OrderRepository {
  @override
  Future<List<model.Order>> fetchForPatient(String patientId) async => const [];
}

final _live = FamilySessionInfo(
  consultationId: 'c1',
  patientName: 'Amina Hassan',
  doctorName: 'Dr Jane Wanjiru',
  specialty: 'ENT',
  status: 'in_progress',
  myStatus: 'invited',
  startedAt: DateTime.now(),
);

Future<void> _render(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(412, 915),
  _Profiles? profiles,
  FakeFamily? family,
  FakeBilling? billing,
  FakeSupport? support,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('p1'),
        currentPatientProfileProvider.overrideWith((ref) async => _profile),
        currentAppUserProvider.overrideWith(
          (ref) async => AppUser.fromMap({
            'id': 'p1',
            'role': 'patient',
            'status': 'active',
            'created_at': DateTime(2026).toIso8601String(),
            'contact_phone': '254712345678',
          }),
        ),
        authRepositoryProvider.overrideWithValue(FakeAuth()),
        profileRepositoryProvider.overrideWithValue(profiles ?? _Profiles()),
        familyRepositoryProvider.overrideWithValue(family ?? FakeFamily()),
        billingRepositoryProvider.overrideWithValue(billing ?? FakeBilling()),
        supportRepositoryProvider.overrideWithValue(support ?? FakeSupport()),
        consultationRepositoryProvider.overrideWithValue(_Consultations()),
        orderRepositoryProvider.overrideWithValue(_Orders()),
        geocoderProvider.overrideWithValue(FakeGeocoder()),
        mapTilesEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('Kenyan phone numbers', () {
    test('normalises common formats', () {
      for (final input in [
        '0712345678',
        '0712 345 678',
        '+254712345678',
        '254 712 345 678',
        '712345678',
      ]) {
        expect(normalizeKenyanPhone(input), '254712345678', reason: input);
      }
      expect(normalizeKenyanPhone('0110123456'), '254110123456');
    });

    test('rejects non-mobile numbers', () {
      for (final input in ['0201234567', '12345', '07123456789', 'abc']) {
        expect(normalizeKenyanPhone(input), isNull, reason: input);
      }
    });

    test('formats for display', () {
      expect(formatKenyanPhone('254712345678'), '0712 345 678');
    });
  });

  group('cards', () {
    test('Luhn check and brand', () {
      expect(isValidCardNumber('4242 4242 4242 4242'), isTrue);
      expect(isValidCardNumber('4242 4242 4242 4241'), isFalse);
      expect(cardBrandOf('4242424242424242'), 'visa');
      expect(cardBrandOf('5555555555554444'), 'mastercard');
      expect(cardBrandOf('378282246310005'), 'amex');
    });
  });

  test('place names are short and readable', () {
    expect(
      Geocoder.shortName({
        'display_name': 'Long, very long, name',
        'address': {
          'town': 'Ruiru',
          'county': 'Kiambu County',
          'country': 'Kenya',
        },
      }),
      'Ruiru, Kiambu, Kenya',
    );
    expect(
      Geocoder.shortName({
        'address': {
          'suburb': 'Kilimani',
          'city': 'Nairobi',
          'state': 'Nairobi County',
          'country': 'Kenya',
        },
      }),
      'Kilimani, Nairobi, Kenya',
    );
  });

  final screens = <String, Widget>{
    'profile hub': const ProfileScreen(),
    'user profile': const AccountScreen(),
    'health details': const HealthDetailsScreen(),
    'location': const PatientLocationScreen(),
    'location picker': const LocationPickerScreen(
      initial: Place(name: 'Ruiru, Kiambu, Kenya', lat: -1.15, lng: 36.96),
    ),
    'family': const FamilyScreen(),
    'billing': const BillingScreen(),
    'support home': const SupportScreen(),
    'new complaint': const NewTicketScreen(kind: SupportKind.complaint),
    'support thread': const TicketScreen(ticketId: 't1'),
  };
  for (final entry in screens.entries) {
    for (final (label, size) in [
      ('phone', const Size(412, 915)),
      ('desktop', const Size(1280, 900)),
    ]) {
      testWidgets('${entry.key} renders ($label)', (tester) async {
        await _render(tester, entry.value, size: size);
        expect(tester.takeException(), isNull);
        await _close(tester);
      });
    }
  }

  testWidgets('profile hub shows the photo header and every category', (
    tester,
  ) async {
    await _render(tester, const ProfileScreen());
    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('amina@example.com'), findsOneWidget);
    for (final label in [
      'User profile',
      'Health details',
      'Location',
      'Family members',
      'Payment methods',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    await tester.scrollUntilVisible(find.text('Report a complaint'), 200);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('Rate GoDoctor'), findsOneWidget);
    // One family invitation is waiting.
    expect(find.text('1 invitation waiting for you'), findsOneWidget);
    await _close(tester);
  });

  testWidgets('health details save blood group and allergies', (tester) async {
    final profiles = _Profiles();
    await _render(tester, const HealthDetailsScreen(), profiles: profiles);
    await tester.scrollUntilVisible(
      find.text('Asthma'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Asthma'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('AB+'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('AB+'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('Save health details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save health details'));
    await _settle(tester);
    expect(profiles.saved?.bloodGroup, 'AB+');
    expect(profiles.saved?.chronicConditions, 'Asthma');
    expect(profiles.saved?.allergies, 'Penicillin');
    expect(
      profiles.saved?.locationName,
      'Ruiru, Kiambu, Kenya',
      reason: 'other sections are kept',
    );
    await _close(tester);
  });

  testWidgets('family: sections by status, and inviting someone', (
    tester,
  ) async {
    final family = FakeFamily();
    await _render(tester, const FamilyScreen(), family: family);
    expect(find.text('INVITATIONS FOR YOU'), findsOneWidget);
    expect(find.text('YOUR FAMILY (2)'), findsOneWidget);
    expect(find.text('WAITING FOR THEM TO ACCEPT'), findsOneWidget);
    expect(find.text('Sibling · Online now'), findsOneWidget);

    await tester.tap(find.text('Invite family'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'baraka@example.com');
    await tester.tap(find.text('Spouse'));
    await tester.tap(find.text('Send invitation'));
    await _settle(tester);
    expect(family.invited?.contact, 'baraka@example.com');
    expect(family.invited?.relationship, 'Spouse');
    await _close(tester);
  });

  testWidgets('billing: a card keeps only brand, last 4 and expiry', (
    tester,
  ) async {
    final billing = FakeBilling();
    await _render(tester, const BillingScreen(), billing: billing);
    expect(find.text('M-Pesa 0712 345 678'), findsOneWidget);
    expect(find.text('Visa •••• 4242'), findsOneWidget);

    await tester.tap(find.text('Add card'));
    await _settle(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '5555 5555 5555 4444');
    await tester.enterText(fields.at(1), '08/30');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(billing.added.single, {
      'kind': 'card',
      'brand': 'mastercard',
      'last4': '4444',
      'month': 8,
      'year': 2030,
    });
    await _close(tester);
  });

  testWidgets('billing: rejects a mistyped card number', (tester) async {
    final billing = FakeBilling();
    await _render(tester, const BillingScreen(), billing: billing);
    await tester.tap(find.text('Add card'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).at(0), '4242 4242 4242 4241');
    await tester.enterText(find.byType(TextField).at(1), '08/30');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(find.text('That card number is not valid.'), findsOneWidget);
    expect(billing.added, isEmpty);
    await _close(tester);
  });

  testWidgets('complaint is sent with its kind', (tester) async {
    final support = FakeSupport();
    await _render(
      tester,
      const NewTicketScreen(kind: SupportKind.complaint),
      support: support,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Tell us what happened'),
      'The chemist gave me the wrong medicine.',
    );
    await tester.pump();
    await tester.tap(find.text('Send'));
    await _settle(tester);
    expect(support.created?.kind, SupportKind.complaint);
    expect(support.created?.subject, 'The chemist gave me the wrong medicine.');
    await _close(tester);
  });

  testWidgets('support thread shows staff replies and sends mine', (
    tester,
  ) async {
    final support = FakeSupport();
    await _render(tester, const TicketScreen(ticketId: 't1'), support: support);
    expect(find.text('GoDoctor support'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Thank you');
    await tester.tap(find.byTooltip('Send'));
    await _settle(tester);
    expect(support.sent, ['Thank you']);
    await _close(tester);
  });

  testWidgets('location picker returns the searched place', (tester) async {
    Place? picked;
    await _render(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => picked = await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LocationPickerScreen(
                  initial: Place(
                    name: 'Nairobi, Kenya',
                    lat: -1.29,
                    lng: 36.82,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Ruiru');
    await tester.pump(const Duration(seconds: 1));
    await _settle(tester);
    await tester.tap(find.text('Ruiru, Kiambu, Kenya'));
    await _settle(tester);
    await tester.tap(find.text('Use this location'));
    await _settle(tester);
    expect(picked?.name, 'Ruiru, Kiambu, Kenya');
    expect(picked?.lat, closeTo(-1.1466, 1e-6));
    await _close(tester);
  });

  testWidgets('family member joins a live session to listen in', (
    tester,
  ) async {
    final family = FakeFamily(info: _live);
    await _render(
      tester,
      const FamilySessionScreen(consultationId: 'c1'),
      family: family,
    );
    expect(
      find.text('Amina Hassan invited you to their consultation'),
      findsOneWidget,
    );
    await tester.tap(find.text('Join and listen'));
    await _settle(tester);
    expect(family.joined, isTrue);
    await _close(tester);
  });

  testWidgets('family session waits until the call starts', (tester) async {
    final family = FakeFamily(
      info: FamilySessionInfo(
        consultationId: 'c1',
        patientName: 'Amina Hassan',
        specialty: 'ENT',
        status: 'awaiting_payment',
        myStatus: 'invited',
      ),
    );
    await _render(
      tester,
      const FamilySessionScreen(consultationId: 'c1'),
      family: family,
    );
    expect(find.text('Waiting for the consultation to start…'), findsOneWidget);
    expect(find.text('Join and listen'), findsNothing);
    await _close(tester);
  });
}
