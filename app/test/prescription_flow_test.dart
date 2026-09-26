// The patient's half of "prescribe during the call": the prescription shows
// up on the call screen with a suggested chemist, and ordering it sends the
// right medicines to the chosen chemist with the prescription attached.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/drug_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/prescription_repository.dart';
import 'package:godoctor_app/features/patient/screens/patient_call_screen.dart';
import 'package:godoctor_app/features/prescription/chemist_match.dart';
import 'package:godoctor_app/features/prescription/prescription_order_screen.dart';

final _now = DateTime.now();

const _para = Drug(
  id: 'para',
  genericName: 'Paracetamol',
  brandNames: ['Panadol'],
  form: 'tablet',
  requiresPrescription: false,
);
const _amox = Drug(
  id: 'amox',
  genericName: 'Amoxicillin',
  brandNames: [],
  form: 'capsule',
  requiresPrescription: true,
);

PrescriptionItem _item(Drug d, int qty) => PrescriptionItem(
  prescriptionId: 'rx1',
  drugId: d.id,
  drug: d,
  drugName: d.genericName,
  dosage: '1 twice daily',
  quantity: qty,
);

final _rx = Prescription(
  id: 'rx1',
  consultationId: 'c1',
  patientId: 'p1',
  doctorId: 'd1',
  source: PrescriptionSource.app,
  issuedAt: _now,
  validUntil: _now.add(const Duration(days: 30)),
  items: [
    _item(_para, 10),
    _item(_amox, 21),
    const PrescriptionItem(
      prescriptionId: 'rx1',
      freeTextName: 'Saline gargle',
      quantity: 1,
    ),
  ],
);

ChemistInventoryItem _stock(
  String chemist,
  String name,
  Drug d, {
  int qty = 100,
  double price = 10,
  double? lat,
}) => ChemistInventoryItem(
  chemistId: chemist,
  chemistName: name,
  drugId: d.id,
  drug: d,
  quantity: qty,
  price: price,
  lastUpdatedAt: _now,
  chemistLat: lat,
  chemistLng: lat == null ? null : 36.8,
);

/// Near chemist has only paracetamol; far chemist has both.
final _allStock = [
  _stock('near', 'Near Pharmacy', _para, price: 5, lat: -1.2921),
  _stock('far', 'Afya Chemist', _para, price: 8, lat: -1.40),
  _stock('far', 'Afya Chemist', _amox, qty: 14, price: 20, lat: -1.40),
];

class _Prescriptions extends PrescriptionRepository {
  @override
  Stream<List<Prescription>> watchForConsultation(String consultationId) =>
      Stream.value([_rx]);
  @override
  Future<Prescription?> fetchById(String id) async => _rx;
}

class _Drugs extends DrugRepository {
  @override
  Future<List<ChemistInventoryItem>> findStockForDrugs(
    List<String> drugIds,
  ) async => _allStock.where((s) => drugIds.contains(s.drugId)).toList();
  @override
  String? imageUrl(String? path) => null;
  @override
  String? inventoryPhotoUrl(String? path) => null;
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<PublicDoctor?> getDoctor(String doctorId) async => const PublicDoctor(
    userId: 'd1',
    name: 'Dr Jane Wanjiru',
    specialties: ['General Practice'],
  );
}

class _Consultations extends ConsultationRepository {
  @override
  Stream<Consultation?> watchConsultation(String consultationId) =>
      Stream.value(
        Consultation(
          id: consultationId,
          patientId: 'p1',
          doctorId: 'd1',
          specialtyRequested: 'General Practice',
          symptomSummary: 'Sore throat',
          status: ConsultationStatus.inProgress,
          createdAt: _now,
          startedAt: _now,
        ),
      );
}

class _Orders extends OrderRepository {
  String? chemistId;
  String? prescriptionId;
  List<CartLine>? lines;

  @override
  Future<String> placeOrder({
    required String chemistId,
    String? prescriptionId,
    required List<CartLine> lines,
    required String fulfillmentType,
  }) async {
    this.chemistId = chemistId;
    this.prescriptionId = prescriptionId;
    this.lines = lines;
    return 'order-1';
  }
}

Future<void> _render(
  WidgetTester tester,
  Widget screen, {
  _Orders? orders,
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
            locationLat: -1.2921,
            locationLng: 36.8,
          ),
        ),
        prescriptionRepositoryProvider.overrideWithValue(_Prescriptions()),
        drugRepositoryProvider.overrideWithValue(_Drugs()),
        doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
        consultationRepositoryProvider.overrideWithValue(_Consultations()),
        orderRepositoryProvider.overrideWithValue(orders ?? _Orders()),
      ],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('rankChemists', () {
    test('prefers the chemist with the most medicines, then distance', () {
      final ranked = rankChemists(
        _rx,
        _allStock,
        patientLat: -1.2921,
        patientLng: 36.8,
      );
      expect(ranked.map((m) => m.chemistId), ['far', 'near']);
      expect(ranked.first.hasEverything, isTrue);
      expect(ranked.first.wanted, 2, reason: 'free-text items are not matched');
      expect(ranked.last.hasEverything, isFalse);
    });

    test('caps quantities at stock and totals them', () {
      final far = rankChemists(_rx, _allStock).first;
      final amox = far.lines.firstWhere((l) => l.item.drugId == 'amox');
      expect(amox.quantity, 14, reason: '21 prescribed, only 14 in stock');
      expect(far.total, 10 * 8 + 14 * 20);
    });

    test('same coverage: nearest first, then cheapest', () {
      final onlyPara = [
        _stock('a', 'A', _para, price: 3, lat: -1.5),
        _stock('b', 'B', _para, price: 9, lat: -1.30),
        _stock('c', 'C', _para, price: 1),
      ];
      final ranked = rankChemists(
        _rx,
        onlyPara,
        patientLat: -1.2921,
        patientLng: 36.8,
      );
      expect(ranked.map((m) => m.chemistId), ['b', 'a', 'c']);
    });

    test('ignores chemists with nothing prescribed or out of stock', () {
      expect(rankChemists(_rx, [_stock('z', 'Z', _para, qty: 0)]), isEmpty);
    });
  });

  testWidgets('prescription appears on the call screen with a suggestion', (
    tester,
  ) async {
    await _render(tester, const PatientCallScreen(consultationId: 'c1'));
    expect(tester.takeException(), isNull);
    expect(find.text('Your prescription'), findsOneWidget);
    expect(find.text('1. Paracetamol'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Order from Afya Chemist'), 300);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Order from Afya Chemist'), findsOneWidget);
    expect(find.textContaining('Has all 2 · '), findsOneWidget);
    await _close(tester);
  });

  testWidgets('ordering a prescription sends its lines to that chemist', (
    tester,
  ) async {
    final orders = _Orders();
    await _render(
      tester,
      const PrescriptionOrderScreen(prescriptionId: 'rx1'),
      orders: orders,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ask the chemist about: Saline gargle.'), findsOneWidget);

    await tester.tap(find.text('Pay with M-Pesa'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(orders.chemistId, 'far');
    expect(orders.prescriptionId, 'rx1');
    expect(
      {for (final l in orders.lines!) l.drugId: l.quantity},
      {'para': 10, 'amox': 14},
    );
    await _close(tester);
  });
}
