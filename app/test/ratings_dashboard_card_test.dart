// Rating pharmacies after an order, the pharmacy dashboard, and the
// patient card doctors and pharmacies can open.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/chemist_dashboard.dart';
import 'package:godoctor_app/data/models/chemist_profile.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/patient_card.dart';
import 'package:godoctor_app/data/models/public_chemist.dart';
import 'package:godoctor_app/data/models/public_doctor.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/chemist/screens/chemist_dashboard_screen.dart';
import 'package:godoctor_app/features/patient/screens/order_tracking_screen.dart';
import 'package:godoctor_app/features/patient_card/patient_card_sheet.dart';

final _now = DateTime.now();

final _dashboard = ChemistDashboard.fromJson({
  'revenue': {
    'today': 500,
    'week': 3200,
    'month': 12000,
    'prev_month': 10000,
    'released': 9000,
    'held': 3000,
  },
  'orders': {
    'today': 2,
    'month': 40,
    'waiting': 1,
    'preparing': 2,
    'ready': 0,
    'disputed': 1,
  },
  'daily': [
    for (var i = 13; i >= 0; i--)
      {
        'day': _now
            .subtract(Duration(days: i))
            .toIso8601String()
            .substring(0, 10),
        'revenue': i * 100,
        'orders': i % 3,
      },
  ],
  'stock': {'listed': 30, 'in_stock': 26, 'low': 3, 'out': 4, 'value': 45000},
  'top': [
    {
      'drug_id': 'a',
      'name': 'Paracetamol (Panadol)',
      'units': 60,
      'revenue': 300,
      'quantity': 12,
    },
    {
      'drug_id': 'b',
      'name': 'Amoxicillin',
      'units': 20,
      'revenue': 800,
      'quantity': 0,
    },
  ],
  'low_stock': [
    {
      'drug_id': 'c',
      'name': 'Cetirizine',
      'quantity': 4,
      'units_30d': 30,
      'days_left': 4,
    },
  ],
  'out_of_stock': [
    {
      'drug_id': 'b',
      'name': 'Amoxicillin',
      'units_30d': 20,
      'last_sold': '2026-09-20',
      'since': '2026-09-21T10:00:00Z',
    },
    {
      'drug_id': 'd',
      'name': 'ORS sachets',
      'units_30d': 0,
      'since': '2026-09-02T10:00:00Z',
    },
  ],
  'slow': [
    {'drug_id': 'e', 'name': 'Vitamin C', 'quantity': 50, 'value': 2500},
  ],
});

class _Orders extends OrderRepository {
  _Orders([this.order]);

  model.Order? order;
  ({String orderId, int rating, String? comment})? review;

  @override
  Future<ChemistDashboard> chemistDashboard() async => _dashboard;

  @override
  Stream<model.Order?> watchOrder(String orderId) async* {
    yield order;
  }

  @override
  Future<model.Order?> fetchOne(String orderId) async => order;

  @override
  Future<void> reviewPharmacy({
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    review = (orderId: orderId, rating: rating, comment: comment);
  }
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<PublicChemist?> getChemist(String chemistId) async =>
      const PublicChemist(
        userId: 'ch1',
        name: 'Afya Chemist',
        ratingAvg: 4.5,
        ratingCount: 12,
      );

  @override
  Future<List<DoctorReview>> chemistReviews(
    String chemistId, {
    int limit = 20,
  }) async => [
    DoctorReview(
      id: 'r1',
      rating: 5,
      comment: 'Well packed · Fair prices',
      createdAt: _now.subtract(const Duration(days: 1)),
    ),
  ];
}

class _Profiles extends ProfileRepository {
  @override
  Future<PatientCard?> patientCard(String patientId) async => PatientCard(
    userId: patientId,
    name: 'Amina Hassan',
    age: 34,
    gender: 'female',
    bloodGroup: 'O+',
    allergies: 'Penicillin, peanuts',
    conditions: 'Asthma',
    medications: '',
    memberSince: DateTime(2025, 6),
    ordersWithMe: 3,
  );

  @override
  String? avatarUrl(String? path) => null;
}

Future<void> _pump(WidgetTester tester, [int times = 8]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
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
      overrides: [currentUserIdProvider.overrideWithValue('ch1'), ...overrides],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await _pump(tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

model.Order _fulfilled({int? rating}) => model.Order.fromMap({
  'id': 'o1',
  'patient_id': 'p1',
  'chemist_id': 'ch1',
  'status': 'fulfilled',
  'total_amount': 360,
  'escrow_status': 'released',
  'fulfillment_type': 'pickup',
  'created_at': _now.subtract(const Duration(hours: 3)).toIso8601String(),
  'fulfilled_at': _now.subtract(const Duration(hours: 1)).toIso8601String(),
  'chemist_profiles': {'business_name': 'Afya Chemist'},
  'order_items': const [],
  'reviews': [
    if (rating != null) {'rating': rating},
  ],
});

void main() {
  test('dashboard numbers: trend, average order, lists', () {
    expect(_dashboard.trend, closeTo(0.2, 0.001));
    expect(_dashboard.averageOrder, 300);
    expect(_dashboard.openOrders, 3);
    expect(_dashboard.daily.length, 14);
    expect(_dashboard.lowStock.single.daysLeft, 4);
    expect(_dashboard.outOfStock.first.units, 20);
    expect(_dashboard.top.first.units, 60);
  });

  test('patient card: allergies, basics, "none" means none', () {
    const card = PatientCard(
      userId: 'p',
      name: 'A',
      age: 34,
      gender: 'female',
      allergies: 'Penicillin; latex',
    );
    expect(card.basics, '34 yrs · Female');
    expect(card.hasAllergies, isTrue);
    expect(PatientCard.items(card.allergies), ['Penicillin', 'latex']);
    expect(
      const PatientCard(userId: 'p', name: '', allergies: 'None').hasAllergies,
      isFalse,
    );
    expect(
      const PatientCard(userId: 'p', name: ' ').displayName,
      'GoDoctor patient',
    );
  });

  test('an order knows whether the patient has rated the pharmacy', () {
    expect(_fulfilled().canRate, isTrue);
    expect(_fulfilled(rating: 4).myRating, 4);
    expect(_fulfilled(rating: 4).canRate, isFalse);
  });

  testWidgets('pharmacy dashboard: sales, stock health, restock, reviews', (
    tester,
  ) async {
    await _host(tester, const ChemistDashboardScreen(), [
      orderRepositoryProvider.overrideWithValue(_Orders()),
      doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
      currentChemistProfileProvider.overrideWith(
        (ref) async => const ChemistProfile(
          userId: 'ch1',
          businessName: 'Afya Chemist',
          verified: true,
          verificationDocuments: [],
        ),
      ),
    ]);
    expect(find.text('Afya Chemist'), findsOneWidget);
    expect(find.textContaining('1 new order is waiting'), findsOneWidget);
    expect(find.text('Sales · last 30 days'), findsOneWidget);
    expect(find.text('+20%'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);
    expect(find.textContaining('a problem reported'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Running low'),
      300,
      scrollable: list,
    );
    expect(find.text('Stock value'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Cetirizine'),
      300,
      scrollable: list,
    );
    expect(find.textContaining('about 4 days'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ORS sachets'),
      300,
      scrollable: list,
    );
    expect(find.textContaining('Sold 20 in the last 30 days'), findsOneWidget);
    expect(find.textContaining('Out since'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Vitamin C'),
      300,
      scrollable: list,
    );
    expect(find.text('60 sold · 12 left'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Well packed · Fair prices'),
      300,
      scrollable: list,
    );
    expect(find.text('4.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('patient card: photo, allergies first, only what is needed', (
    tester,
  ) async {
    await _host(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () =>
                  showPatientCard(context, 'p1', forPharmacy: true),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      [profileRepositoryProvider.overrideWithValue(_Profiles())],
    );
    await tester.tap(find.text('open'));
    await _pump(tester);
    expect(find.text('Amina Hassan'), findsOneWidget);
    expect(find.text('34 yrs · Female'), findsOneWidget);
    expect(find.text('Allergies'), findsOneWidget);
    expect(find.text('Penicillin'), findsOneWidget);
    expect(find.text('peanuts'), findsOneWidget);
    expect(find.text('Asthma'), findsOneWidget);
    expect(find.text('Orders with you'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('contact details'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('rate the pharmacy from a completed order', (tester) async {
    final orders = _Orders(_fulfilled());
    await _host(tester, const OrderTrackingScreen(orderId: 'o1'), [
      orderRepositoryProvider.overrideWithValue(orders),
    ]);
    await tester.scrollUntilVisible(
      find.text('How was Afya Chemist?'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Rate 4'));
    await _pump(tester);
    expect(find.text('How was your order?'), findsOneWidget);
    expect(find.text('Very good'), findsOneWidget, reason: '4 stars chosen');
    await tester.tap(find.text('Quick service'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Friendly staff');
    await tester.tap(find.text('Submit review'));
    await _pump(tester);
    expect(orders.review?.rating, 4);
    expect(orders.review?.comment, 'Quick service. Friendly staff');
    expect(find.text('How was your order?'), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('a rated order thanks the patient instead', (tester) async {
    await _host(tester, const OrderTrackingScreen(orderId: 'o1'), [
      orderRepositoryProvider.overrideWithValue(_Orders(_fulfilled(rating: 5))),
    ]);
    await tester.scrollUntilVisible(
      find.text('Thanks for your review'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byTooltip('Rate 4'), findsNothing);
    await _close(tester);
  });
}
