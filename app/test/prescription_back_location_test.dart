// The paper-style prescription (and its PDF), the phone's back button, and
// "most convenient chemist first" matching.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/exit_guard.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/medication.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/drug_repository.dart';
import 'package:godoctor_app/features/location/location_picker_screen.dart'
    show geocoderProvider;
import 'package:godoctor_app/features/patient/screens/chemist_select_screen.dart';
import 'package:godoctor_app/features/prescription/digital_prescription.dart';
import 'package:godoctor_app/features/prescription/prescription_pdf.dart';
import 'package:godoctor_app/features/prescription/rx_line.dart';
import 'package:godoctor_app/services/chemist_matching.dart';
import 'package:godoctor_app/services/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fakes.dart';

const _amox = Drug(
  id: 'amox',
  genericName: 'Amoxicillin',
  brandNames: [],
  form: 'capsule',
  requiresPrescription: true,
);

const _items = [
  PrescriptionItem(
    prescriptionId: 'rx',
    drugId: 'amox',
    drugName: 'Amoxicillin',
    drug: _amox,
    dosage: '1 capsule three times daily',
    instructions: 'After meals',
    quantity: 15,
  ),
  PrescriptionItem(
    prescriptionId: 'rx',
    freeTextName: 'Saline gargle',
    dosage: 'as needed',
    quantity: 1,
  ),
];

ChemistInventoryItem _stock(String id, double price, double? lat) =>
    ChemistInventoryItem(
      chemistId: id,
      chemistName: 'Chemist $id',
      drugId: 'amox',
      drug: _amox,
      quantity: 20,
      price: price,
      lastUpdatedAt: DateTime(2026),
      chemistLat: lat,
      chemistLng: lat == null ? null : 36.82,
    );

class _Drugs extends DrugRepository {
  @override
  Future<List<ChemistInventoryItem>> findStockForDrug(String drugId) async => [
    _stock('far-cheap', 50, -1.40),
    _stock('near', 90, -1.2865),
    _stock('nowhere', 10, null),
  ];
  @override
  String? inventoryPhotoUrl(String? path) => null;
}

void main() {
  group('reading the dose', () {
    test('only says what the doctor wrote', () {
      expect(dosesPerDayIn('1 capsule three times daily'), 3);
      expect(dosesPerDayIn('2 tablets at night'), 1);
      expect(dosesPerDayIn('as needed'), isNull, reason: 'no guessing');
      expect(courseDaysIn(dosage: 'twice daily for 2 weeks', perDay: 2), 14);
      expect(courseDaysIn(dosage: '1 tablet', quantity: 12, perDay: 3), 4);
      expect(courseDaysIn(dosage: 'as needed'), isNull);
    });

    test('a prescription line', () {
      final l = RxLine.of(_items.first);
      expect(l.form, 'capsule');
      expect(l.timesLabel, '3 times');
      expect(l.days, 5);
      expect(l.note, 'After meals');
      final free = RxLine.of(_items.last);
      expect(free.timesDaily, isNull);
      expect(free.days, isNull);
    });
  });

  testWidgets('the prescription reads like the paper one', (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.patientTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DigitalPrescription(
              doctorName: 'Dr Jane Wanjiru',
              doctorDetail: 'General Practice',
              patientName: 'Amina Hassan',
              patientAge: 34,
              patientGender: 'Female',
              items: _items,
              issuedAt: DateTime(2026, 9, 27),
              validUntil: DateTime(2026, 10, 27),
              reference: 'a1b2c3d4e5',
            ),
          ),
        ),
      ),
    );
    for (final t in ['Patient:', 'Age:', 'Gender:', 'Date:', 'Rx']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Ref A1B2C3D4'), findsOneWidget);
    expect(find.text('3 times'), findsOneWidget);
    expect(find.text('Amoxicillin (capsule)'), findsOneWidget);
    // The signature is the doctor's name.
    expect(find.text('Dr Jane Wanjiru'), findsOneWidget);
    expect(find.text('Dr Jane Wanjiru · General Practice'), findsOneWidget);
    expect(find.text('Save or share as PDF'), findsOneWidget);
    expect(find.text('DRAFT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a draft is marked and can\'t be exported yet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DigitalPrescription(
              doctorName: 'Dr Jane',
              patientName: 'Amina',
              items: _items,
              onRemoveItem: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('DRAFT'), findsOneWidget);
    expect(find.text('Save or share as PDF'), findsNothing);
    expect(find.byTooltip('Remove'), findsNWidgets(2));
  });

  test('the PDF copy', () async {
    final bytes = await buildPrescriptionPdf(
      PrescriptionPdfData(
        doctorName: 'Dr Jane Wanjiru',
        patientName: 'Amina “Mama” Hassan – Ruiru',
        issuedAt: DateTime(2026, 9, 27),
        lines: [for (final i in _items) RxLine.of(i)],
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, lessThan(200 * 1024), reason: 'light to share');
    expect(pdfSafe('Amina “Mama” – Ruiru'), 'Amina "Mama" - Ruiru');
  });

  group('back button', () {
    testWidgets('home: first press warns, second leaves the app', (
      tester,
    ) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: ExitGuard(child: Scaffold(body: Text('home'))),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(calls, isNot(contains('SystemNavigator.pop')));

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(calls, contains('SystemNavigator.pop'));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('another tab: back goes Home instead', (tester) async {
      var wentHome = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ExitGuard(
            onBack: () => wentHome = true,
            child: const Scaffold(body: Text('chats')),
          ),
        ),
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(wentHome, isTrue);
      expect(find.text('Press back again to exit'), findsNothing);
    });
  });

  group('matching chemists', () {
    const here = MatchPoint(
      lat: -1.2864,
      lng: 36.8172,
      source: MatchSource.profile,
    );

    test('close first; a much cheaper one nearby can win; unknown last', () {
      final ranked = rankByConvenience([
        _stock('far-cheap', 50, -1.40),
        _stock('near', 90, -1.2865),
        _stock('near-cheaper', 80, -1.2880),
        _stock('nowhere', 10, null),
      ], here);
      expect(ranked.map((r) => r.item.chemistId), [
        'near-cheaper',
        'near',
        'far-cheap',
        'nowhere',
      ]);
      expect(ranked.first.km, lessThan(1));
      expect(ranked.last.km, isNull);
    });

    test('without any location, cheapest first', () {
      final ranked = rankByConvenience([
        _stock('a', 90, -1.2865),
        _stock('b', 50, -1.40),
      ], null);
      expect(ranked.first.item.chemistId, 'b');
    });

    test('distances read naturally', () {
      expect(distanceLabel(0.42), '420 m');
      expect(distanceLabel(3.46), '3.5 km');
    });

    test('a searched place beats the profile location', () {
      final m = MatchingLocation(FakeGeocoder());
      MatchPoint? now;
      m.addListener((s) => now = s);
      m.useProfile(
        const PatientProfile(
          userId: 'p',
          name: 'A',
          locationLat: -1.14,
          locationLng: 36.96,
          locationName: 'Ruiru',
        ),
      );
      expect(now?.source, MatchSource.profile);
      m.useCustom(const Place(name: 'Westlands', lat: -1.26, lng: 36.80));
      m.useProfile(
        const PatientProfile(
          userId: 'p',
          name: 'A',
          locationLat: -1.0,
          locationLng: 37.0,
        ),
      );
      expect(now?.label, 'Westlands');
    });

    testWidgets('chemists near the patient, with the location offer', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
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
                locationName: 'Nairobi CBD, Nairobi, Kenya',
              ),
            ),
            drugRepositoryProvider.overrideWithValue(_Drugs()),
            geocoderProvider.overrideWithValue(FakeGeocoder()),
          ],
          child: MaterialApp(
            theme: AppTheme.patientTheme,
            home: const ChemistSelectScreen(drugId: 'amox'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The phone's location isn't available in tests; if the gentle offer
      // to turn it on shows, decline it.
      if (find.text('Not now').evaluate().isNotEmpty) {
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Near Nairobi CBD, Nairobi'), findsOneWidget);
      expect(find.text('Near you'), findsOneWidget);
      expect(find.text('Best match'), findsOneWidget);
      expect(find.text('Chemist near'), findsOneWidget);
      expect(find.text('Further away'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
