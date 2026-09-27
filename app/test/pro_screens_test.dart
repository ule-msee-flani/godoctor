// Renders every doctor, chemist and admin screen the way the router does
// (professional theme inside the patient-themed MaterialApp) with realistic
// fake data, and fails on any rendering error -- the "red screen" in debug.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/pending_verification_view.dart';
import 'package:godoctor_app/data/models/app_user.dart';
import 'package:godoctor_app/data/models/chemist_profile.dart';
import 'package:godoctor_app/data/models/consultation.dart';
import 'package:godoctor_app/data/models/doctor_profile.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/appointment_repository.dart';
import 'package:godoctor_app/data/repositories/consultation_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/doctor_schedule_repository.dart';
import 'package:godoctor_app/data/repositories/drug_repository.dart';
import 'package:godoctor_app/data/repositories/notification_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/prescription_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/admin/screens/admin_verification_screen.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_account_screen.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_inventory_screen.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_onboarding_screen.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_orders_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_call_screen.dart';
import 'package:godoctor_app/features/doctor/widgets/visit_summary_editor.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_dashboard_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_history_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_medicines_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_onboarding_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_profile_edit_screen.dart';
import 'package:godoctor_app/features/doctor/screens/doctor_schedule_screen.dart';
import 'package:godoctor_app/features/patient/screens/consultation_history_screen.dart';
import 'package:godoctor_app/features/patient/screens/order_history_screen.dart';

import 'support/fakes.dart';

const _uid = 'user-1';
final _now = DateTime.now();

const _doctor = DoctorProfile(
  userId: _uid,
  name: 'Dr Jane Wanjiru',
  specialties: ['General Practice', 'Pediatrics'],
  licenseNumber: 'KMPDC-123',
  licenseVerified: true,
  verificationDocuments: [],
  status: DoctorStatus.available,
  ratingAvg: 4.6,
  ratingCount: 12,
  bio: 'GP with 10 years of experience.',
  consultationFee: 1500,
  languages: ['English', 'Swahili'],
  gender: 'female',
  yearsExperience: 10,
);

final _consultation = Consultation(
  id: 'c1',
  patientId: 'p1',
  doctorId: _uid,
  specialtyRequested: 'General Practice',
  symptomSummary: 'Fever and headache for two days',
  status: ConsultationStatus.scheduled,
  createdAt: _now,
  mode: ConsultationMode.scheduled,
  scheduledFor: _now.add(const Duration(minutes: 5)),
  scheduledEnd: _now.add(const Duration(minutes: 35)),
  feeAmount: 1500,
);

class _Consultations extends ConsultationRepository {
  @override
  Stream<List<Consultation>> watchActiveForDoctor(String doctorId) =>
      Stream.value([
        Consultation(
          id: 'c-pay',
          patientId: 'p1',
          doctorId: _uid,
          specialtyRequested: 'ENT',
          symptomSummary: 'Ear pain for 3 days',
          status: ConsultationStatus.awaitingPayment,
          createdAt: _now,
          feeAmount: 800,
          paymentDueAt: _now.add(const Duration(minutes: 9)),
        ),
        Consultation(
          id: 'c-paid',
          patientId: 'p1',
          doctorId: _uid,
          specialtyRequested: 'ENT',
          symptomSummary: 'Sore throat',
          status: ConsultationStatus.inProgress,
          createdAt: _now,
          feeAmount: 800,
        ),
      ]);
  @override
  Stream<List<ConsultationOffer>> watchOffersForDoctor(String doctorId) =>
      Stream.value([
        ConsultationOffer(
          id: 'o1',
          consultationId: 'c9',
          doctorId: _uid,
          status: OfferStatus.pending,
          offeredAt: _now,
          expiresAt: _now.add(const Duration(seconds: 25)),
        ),
      ]);
  @override
  Future<List<Consultation>> fetchHistoryForDoctor(String doctorId) async => [
    _consultation,
  ];
  @override
  Future<List<Consultation>> fetchHistoryForPatient(String patientId) async => [
    _consultation,
  ];
  @override
  Future<Consultation?> fetchById(String consultationId) async => _consultation;
  @override
  Future<IntakeForm?> fetchIntakeForm(String consultationId) async =>
      const IntakeForm(
        consultationId: 'c1',
        symptoms: 'Fever and headache',
        duration: 'Few days',
        severity: 'Moderate',
        flaggedEmergency: false,
      );
  @override
  Future<void> markDoctorJoined(String consultationId) async {}
  @override
  Future<Map<String, dynamic>> doctorTodayStats() async => {
    'patients': 3,
    'earnings': 2400,
    'rating': 4.8,
    'ratings': 12,
    'open_chats': 2,
  };
  @override
  Future<void> saveVisitSummary(
    String consultationId, {
    String? summary,
    String? redFlags,
    DateTime? followUpOn,
  }) async {
    savedSummary = (
      summary: summary,
      redFlags: redFlags,
      followUpOn: followUpOn,
    );
  }
}

/// What the doctor saved from the Summary tab.
({String? summary, String? redFlags, DateTime? followUpOn})? savedSummary;

class _Appointments extends AppointmentRepository {
  @override
  Future<List<Consultation>> upcomingForDoctor(String doctorId) async => [
    _consultation,
  ];
}

class _Notifications extends NotificationRepository {
  @override
  Stream<List<AppNotificationItem>> watch(String userId) => Stream.value([]);
}

/// Last value the doctor switched to; set [availabilityError] to fail.
bool? availabilitySet;
Object? availabilityError;

class _Profiles extends ProfileRepository {
  @override
  Future<void> setDoctorAvailability(bool available) async {
    if (availabilityError != null) throw availabilityError!;
    availabilitySet = available;
  }

  @override
  Future<PatientProfile?> fetchPatientProfile(String userId) async =>
      const PatientProfile(
        userId: 'p1',
        name: 'Amina Hassan',
        allergies: 'Penicillin',
      );
  @override
  Future<List<DoctorProfile>> fetchPendingDoctors() async => [
    const DoctorProfile(
      userId: 'd2',
      name: 'Dr Pending',
      specialties: ['ENT'],
      licenseNumber: 'KMPDC-9',
      licenseVerified: false,
      verificationDocuments: [],
      status: DoctorStatus.offline,
      ratingAvg: 0,
    ),
  ];
  @override
  Future<List<ChemistProfile>> fetchPendingChemists() async => [
    const ChemistProfile(
      userId: 'ch2',
      businessName: 'Afya Chemist',
      registrationNumber: 'PPB-1',
      verified: false,
      verificationDocuments: [],
    ),
  ];
}

class _Schedule extends DoctorScheduleRepository {
  @override
  Future<List<AvailabilityWindow>> fetchAvailability() async => const [
    AvailabilityWindow(id: 'w1', weekday: 1, start: '09:00', end: '12:00'),
  ];
  @override
  Future<List<TimeOff>> fetchTimeOff() async => [
    TimeOff(
      id: 't1',
      startsAt: _now.add(const Duration(days: 3)),
      endsAt: _now.add(const Duration(days: 5)),
      reason: 'Conference',
    ),
  ];
}

const _paracetamol = Drug(
  id: 'd1',
  genericName: 'Paracetamol',
  brandNames: ['Panadol'],
  form: 'tablet',
  requiresPrescription: false,
);

const _catalog = [
  _paracetamol,
  Drug(
    id: 'd2',
    genericName: 'Amoxicillin',
    brandNames: ['Amoxil'],
    form: 'capsule',
    requiresPrescription: true,
  ),
  Drug(
    id: 'd3',
    genericName: 'Cough syrup',
    brandNames: [],
    form: 'syrup',
    requiresPrescription: false,
  ),
];

/// Last prescription the fake repository was asked to send.
List<PrescriptionItem>? sentItems;

final _prescription = Prescription(
  id: 'rx-123456789',
  consultationId: 'c1',
  patientId: 'p1',
  doctorId: _uid,
  source: PrescriptionSource.app,
  issuedAt: _now,
  validUntil: _now.add(const Duration(days: 30)),
  items: const [
    PrescriptionItem(
      prescriptionId: 'rx-123456789',
      drugId: 'd1',
      drug: _paracetamol,
      drugName: 'Paracetamol',
      dosage: '1 tablet three times daily',
      quantity: 15,
      instructions: 'After food',
    ),
    PrescriptionItem(
      prescriptionId: 'rx-123456789',
      freeTextName: 'Saline gargle',
      quantity: 1,
    ),
  ],
);

class _Prescriptions extends PrescriptionRepository {
  @override
  Stream<List<Prescription>> watchForConsultation(String consultationId) =>
      Stream.value([_prescription]);
  @override
  Future<Prescription?> fetchById(String id) async => _prescription;
  @override
  Future<List<PrescriptionItem>> usualPrescriptions({int limit = 6}) async => [
    const PrescriptionItem(
      prescriptionId: '',
      drugId: 'd1',
      drugName: 'Paracetamol',
      dosage: '2 tablets three times daily',
      quantity: 18,
    ),
  ];
  @override
  Future<String> issueForConsultation({
    required String consultationId,
    required List<PrescriptionItem> items,
    int validDays = 30,
  }) async {
    sentItems = items;
    return 'rx-new';
  }
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<PublicDoctor?> getDoctor(String doctorId) async => const PublicDoctor(
    userId: _uid,
    name: 'Dr Jane Wanjiru',
    specialties: ['General Practice'],
  );
  @override
  String? avatarUrl(String? path) => null;
}

class _Drugs extends DrugRepository {
  @override
  Future<List<Drug>> fetchCatalog() async => _catalog;
  @override
  Future<List<ChemistInventoryItem>> findStockForDrug(String drugId) async =>
      fetchChemistInventory(_uid);
  @override
  String? imageUrl(String? path) => null;
  @override
  Future<List<ChemistInventoryItem>> fetchChemistInventory(
    String chemistId,
  ) async => [
    ChemistInventoryItem(
      chemistId: _uid,
      drugId: 'd1',
      quantity: 40,
      price: 50,
      lastUpdatedAt: _now,
      drug: const Drug(
        id: 'd1',
        genericName: 'Paracetamol',
        brandNames: ['Panadol'],
        form: 'tablet',
        requiresPrescription: false,
      ),
    ),
  ];
  @override
  String? inventoryPhotoUrl(String? path) => null;
}

class _Orders extends OrderRepository {
  @override
  Future<List<model.Order>> fetchForPatient(String patientId) =>
      watchForChemist('x').first;
  @override
  Stream<List<model.Order>> watchForChemist(String chemistId) => Stream.value([
    for (final status in [
      OrderStatus.placed,
      OrderStatus.confirmed,
      OrderStatus.ready,
    ])
      model.Order(
        id: 'o-${status.name}',
        patientId: 'p1',
        chemistId: _uid,
        status: status,
        totalAmount: 250,
        escrowStatus: EscrowStatus.held,
        fulfillmentType: FulfillmentType.pickup,
        createdAt: _now,
        chemistName: 'Afya Chemist',
        items: const [
          model.OrderItem(
            orderId: 'o1',
            drugId: 'd1',
            quantity: 2,
            unitPrice: 50,
            drugName: 'Paracetamol',
            drug: _paracetamol,
          ),
        ],
        prescriptionId: status == OrderStatus.placed ? 'rx-123456789' : null,
      ),
  ]);
}

Future<void> _render(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(1280, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue(_uid),
        currentDoctorProfileProvider.overrideWith((ref) async => _doctor),
        currentChemistProfileProvider.overrideWith(
          (ref) async => const ChemistProfile(
            userId: _uid,
            businessName: 'Afya Chemist',
            verified: true,
            verificationDocuments: [],
          ),
        ),
        currentAppUserProvider.overrideWith(
          (ref) async => AppUser.fromMap({
            'id': _uid,
            'role': 'doctor',
            'status': 'active',
            'created_at': _now.toIso8601String(),
          }),
        ),
        consultationRepositoryProvider.overrideWithValue(_Consultations()),
        appointmentRepositoryProvider.overrideWithValue(_Appointments()),
        notificationRepositoryProvider.overrideWithValue(_Notifications()),
        profileRepositoryProvider.overrideWithValue(_Profiles()),
        doctorScheduleRepositoryProvider.overrideWithValue(_Schedule()),
        drugRepositoryProvider.overrideWithValue(_Drugs()),
        orderRepositoryProvider.overrideWithValue(_Orders()),
        prescriptionRepositoryProvider.overrideWithValue(_Prescriptions()),
        doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
        authRepositoryProvider.overrideWithValue(FakeAuth()),
        familyRepositoryProvider.overrideWithValue(FakeFamily()),
        supportRepositoryProvider.overrideWithValue(FakeSupport()),
      ],
      child: MaterialApp(
        theme: AppTheme.patientTheme,
        // Same wrapping as `_pro()` in app_router.dart.
        home: Theme(data: AppTheme.professionalTheme, child: screen),
      ),
    ),
  );
  // Let futures/streams resolve; don't wait for periodic timers to finish.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  dialogTests();
  callTests();

  testWidgets('doctor goes offline and back; a refusal is explained', (
    tester,
  ) async {
    availabilitySet = null;
    availabilityError = null;
    await _render(
      tester,
      const DoctorDashboardScreen(),
      size: const Size(412, 915),
    );
    expect(find.text('Available for consultations'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(availabilitySet, isFalse);

    availabilityError = Exception('doctor is not yet verified');
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('not been verified'), findsOneWidget);
    expect(tester.takeException(), isNull);
    availabilityError = null;
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
  final screens = <String, Widget>{
    'doctor dashboard': const DoctorDashboardScreen(),
    'doctor onboarding': const DoctorOnboardingScreen(),
    'doctor pending': const PendingVerificationView(
      title: 'Your license is under review',
      description: 'An admin checks the register.',
    ),
    'doctor history': const DoctorHistoryScreen(),
    'doctor schedule': const DoctorScheduleScreen(),
    'doctor profile edit': const DoctorProfileEditScreen(),
    'doctor call': const DoctorCallScreen(consultationId: 'c1'),
    'doctor medicines': const DoctorMedicinesScreen(),
    'chemist onboarding': const ChemistOnboardingScreen(),
    'chemist inventory': const ChemistInventoryScreen(),
    'chemist orders': const ChemistOrdersScreen(),
    'chemist account': const ChemistAccountScreen(),
    'admin verification': const AdminVerificationScreen(),
    // Same untyped-provider crash lived in these two patient screens.
    'patient consultation history': const ConsultationHistoryScreen(),
    'patient order history': const OrderHistoryScreen(),
  };

  for (final entry in screens.entries) {
    for (final (label, size) in [
      ('desktop', const Size(1280, 900)),
      ('phone', const Size(412, 915)),
    ]) {
      testWidgets('${entry.key} renders ($label)', (tester) async {
        await _render(tester, entry.value, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        // Close the screen so countdown/clock timers stop before the test ends.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}

void dialogTests() {
  // Dialogs and sheets open ABOVE the screen's professional Theme, so they
  // use the app's patient theme (full-width buttons). Make sure they still lay
  // out without errors.
  Future<void> openAndCheck(
    WidgetTester tester,
    Widget screen,
    Finder trigger,
  ) async {
    await _render(tester, screen, size: const Size(412, 915));
    await tester.tap(trigger);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('chemist stock "Edit" dialog lays out', (tester) async {
    await openAndCheck(
      tester,
      const ChemistInventoryScreen(),
      find.text('Edit'),
    );
  });

  testWidgets('chemist can open the prescription on an order', (tester) async {
    await openAndCheck(
      tester,
      const ChemistOrdersScreen(),
      find.text('Check the prescription'),
    );
  });

  testWidgets('doctor "Add hours" dialog lays out', (tester) async {
    await openAndCheck(
      tester,
      const DoctorScheduleScreen(),
      find.text('Add hours'),
    );
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void callTests() {
  testWidgets('doctor prescribes during the call and sends it', (tester) async {
    sentItems = null;
    await _render(
      tester,
      const DoctorCallScreen(consultationId: 'c1'),
      size: const Size(412, 915),
    );

    await tester.tap(find.text('Medicines'));
    await _settle(tester);
    expect(find.text('Paracetamol'), findsWidgets);

    await tester.tap(find.text('Prescribe'));
    await _settle(tester);
    await tester.tap(find.text('1 tablet twice daily'));
    await tester.pump();
    await tester.ensureVisible(find.text('Add to prescription'));
    await tester.tap(find.text('Add to prescription'));
    await _settle(tester);

    // The medicine is now marked on the showcase and counted on the tab.
    expect(find.text('Edit dose'), findsOneWidget);
    await tester.tap(find.text('Prescription (1)'));
    await _settle(tester);
    expect(find.text('1 tablet twice daily'), findsOneWidget);

    // The "Added ..." message sits over the bottom of the screen.
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pump();
    await tester.ensureVisible(find.text('Send to Amina Hassan'));
    await tester.pump();
    await tester.tap(find.text('Send to Amina Hassan'));
    await _settle(tester);
    expect(sentItems?.single.drugId, 'd1');
    expect(sentItems?.single.dosage, '1 tablet twice daily');
    expect(
      find.text('Prescription (1)'),
      findsNothing,
      reason: 'draft cleared',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('doctor prescribes one of their usual medicines', (tester) async {
    sentItems = null;
    await _render(
      tester,
      const DoctorCallScreen(consultationId: 'c1'),
      size: const Size(412, 915),
    );
    await tester.tap(find.text('Medicines'));
    await _settle(tester);
    expect(find.text('Your usual'), findsOneWidget);
    final usual = find.text('Paracetamol · 2 tablets three times daily');
    await tester.ensureVisible(usual);
    await tester.pump();
    await tester.tap(usual);
    await _settle(tester);
    // The dose sheet opens already filled in with the usual dose.
    await tester.ensureVisible(find.text('Add to prescription'));
    await tester.tap(find.text('Add to prescription'));
    await _settle(tester);
    await tester.tap(find.text('Prescription (1)'));
    await _settle(tester);
    expect(find.text('2 tablets three times daily'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('doctor writes the visit summary for the patient', (
    tester,
  ) async {
    savedSummary = null;
    await _render(
      tester,
      const DoctorCallScreen(consultationId: 'c1'),
      size: const Size(412, 915),
    );
    // Four tabs scroll on a phone.
    await tester.ensureVisible(find.text('Summary'));
    await tester.pump();
    await tester.tap(find.text('Summary'));
    await _settle(tester);
    final summaryList = find
        .descendant(
          of: find.byType(VisitSummaryEditor),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.tap(find.text('Viral infection'));
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('Difficulty breathing or chest pain').hitTestable(),
      summaryList,
      const Offset(0, -150),
    );
    await tester.pump();
    await tester.tap(find.text('Difficulty breathing or chest pain'));
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('In 1 week').hitTestable(),
      summaryList,
      const Offset(0, -150),
    );
    await tester.pump();
    await tester.tap(find.text('In 1 week'));
    await tester.pump();
    await tester.dragUntilVisible(
      find.text('Save summary').hitTestable(),
      summaryList,
      const Offset(0, -150),
    );
    await tester.pump();
    await tester.tap(find.text('Save summary'));
    await _settle(tester);

    expect(savedSummary?.summary, contains('viral infection'));
    expect(savedSummary?.redFlags, 'Difficulty breathing or chest pain');
    expect(savedSummary?.followUpOn, isNotNull);
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('doctor can shrink the video to a floating window', (
    tester,
  ) async {
    await _render(
      tester,
      const DoctorCallScreen(consultationId: 'c1'),
      size: const Size(412, 915),
    );
    await tester.tap(find.byTooltip('Shrink video'));
    await _settle(tester);
    expect(find.byTooltip('Enlarge video'), findsOneWidget);
    await tester.drag(find.byTooltip('Enlarge video'), const Offset(-120, 80));
    await _settle(tester);
    await tester.tap(find.byTooltip('Enlarge video'));
    await _settle(tester);
    expect(find.byTooltip('Shrink video'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
