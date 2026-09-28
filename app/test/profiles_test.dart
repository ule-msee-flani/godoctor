// Doctor and pharmacy pages as patients see them: their photo on top (or
// initials), who they are, track record, reviews / stock, and the button
// to book or buy.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/profile_hero.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/public_chemist.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/drug_repository.dart';
import 'package:godoctor_app/features/location/location_picker_screen.dart';
import 'package:godoctor_app/features/patient/chemist/chemist_profile_screen.dart';
import 'package:godoctor_app/features/patient/screens/doctor_profile_screen.dart';

import 'support/fakes.dart';

const _para = Drug(
  id: 'para',
  genericName: 'Paracetamol',
  brandNames: ['Panadol'],
  form: 'tablet',
  requiresPrescription: false,
);

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<PublicDoctor?> getDoctor(String doctorId) async => PublicDoctor(
    nextSlot: DateTime.now().add(const Duration(days: 1)),
    userId: 'd1',
    name: 'Dr Jane Wanjiru',
    specialties: ['General Practice', 'Pediatrics'],
    bio: 'I have looked after families in Nairobi for twelve years.',
    consultationFee: 800,
    languages: ['English', 'Swahili'],
    yearsExperience: 12,
    ratingAvg: 4.5,
    ratingCount: 2,
    availableNow: true,
  );

  @override
  Future<List<DoctorReview>> reviews(
    String doctorId, {
    int limit = 20,
    int offset = 0,
  }) async => [
    DoctorReview(
      id: 'r1',
      rating: 5,
      comment: 'Very patient and clear.',
      createdAt: DateTime(2026, 9, 20),
    ),
    DoctorReview(id: 'r2', rating: 4, createdAt: DateTime(2026, 9, 21)),
  ];

  @override
  Future<DoctorPublicStats> publicStats(String doctorId) async =>
      DoctorPublicStats(
        consultations: 148,
        patients: 120,
        memberSince: DateTime(2026, 3),
      );

  @override
  Future<PublicChemist?> getChemist(String chemistId) async => PublicChemist(
    userId: 'ch1',
    name: 'Afya Chemist',
    contactPhone: '0712345678',
    locationName: 'Kilimani, Nairobi',
    lat: -1.29,
    lng: 36.79,
    memberSince: DateTime(2026, 5),
    medicinesInStock: 42,
    ordersFilled: 310,
    ratingAvg: 3.5,
    ratingCount: 2,
  );

  @override
  Future<List<DoctorReview>> chemistReviews(
    String chemistId, {
    int limit = 20,
  }) async => [
    DoctorReview(
      id: 'r1',
      rating: 5,
      comment: 'Quick service · Helpful pharmacist',
      createdAt: DateTime(2026, 9, 20),
    ),
    DoctorReview(
      id: 'r2',
      rating: 2,
      comment: 'Had to wait long',
      createdAt: DateTime(2026, 9, 18),
    ),
  ];
}

class _Drugs extends DrugRepository {
  @override
  Future<List<ChemistInventoryItem>> publicStock(
    String chemistId, {
    int limit = 60,
  }) async => [
    ChemistInventoryItem(
      chemistId: 'ch1',
      chemistName: 'Afya Chemist',
      drugId: 'para',
      drug: _para,
      quantity: 30,
      price: 50,
      lastUpdatedAt: DateTime(2026),
    ),
  ];
  @override
  String? imageUrl(String? path) => null;
  @override
  String? inventoryPhotoUrl(String? path) => null;
}

Future<void> _render(WidgetTester tester, Widget screen) async {
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
            name: 'Amina',
            locationLat: -1.2864,
            locationLng: 36.8172,
          ),
        ),
        doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
        drugRepositoryProvider.overrideWithValue(_Drugs()),
        geocoderProvider.overrideWithValue(FakeGeocoder()),
        mapTilesEnabledProvider.overrideWithValue(false),
      ],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  // The "online" dot breathes forever, so pump a few frames instead of
  // waiting for everything to settle.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('doctor page: photo header, who they are, record, reviews', (
    tester,
  ) async {
    await _render(tester, const DoctorProfileScreen(doctorId: 'd1'));
    expect(find.byType(ProfileHeroScaffold), findsOneWidget);
    expect(find.text('JW'), findsOneWidget, reason: 'initials without a photo');
    expect(find.text('Dr Jane Wanjiru'), findsWidgets);
    expect(find.text('General Practice · Pediatrics'), findsOneWidget);
    expect(find.text('Available now'), findsOneWidget);
    expect(find.text('Licence verified'), findsOneWidget);
    expect(find.text('12 yrs'), findsOneWidget);
    expect(find.text('148'), findsOneWidget);
    expect(find.text('About Dr Jane'), findsOneWidget);
    expect(find.text('Book appointment'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('What patients say'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Very patient and clear.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('2 reviews'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pharmacy page: where, track record, stock, buy here', (
    tester,
  ) async {
    await _render(
      tester,
      ChemistProfileScreen(
        chemistId: 'ch1',
        item: ChemistInventoryItem(
          chemistId: 'ch1',
          drugId: 'para',
          drug: _para,
          quantity: 30,
          price: 50,
          lastUpdatedAt: DateTime(2026),
        ),
      ),
    );
    expect(find.text('Afya Chemist'), findsWidgets);
    expect(find.textContaining('Kilimani, Nairobi'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.text('310'), findsOneWidget);
    expect(find.text('Orders filled'), findsOneWidget);
    expect(find.text('Buy here'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Get directions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('In stock'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The medicine's name is in the stock list and the buy bar.
    await tester.scrollUntilVisible(
      find.text('Buy'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Paracetamol (Panadol)'), findsNWidgets(2));

    // The average of everyone's ratings, and what they said.
    expect(find.text('3.5 ★'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Had to wait long'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('What patients say'), findsOneWidget);
    expect(find.text('Quick service · Helpful pharmacist'), findsOneWidget);
    expect(find.text('2 reviews'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
