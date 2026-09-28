// Live order tracking (confirm receipt, report a problem), friendly order
// errors, visit grouping, the pharmacies directory and importing a
// pharmacy's existing stock.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/order.dart' as model;
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/public_chemist.dart';
import 'package:godoctor_app/data/models/visit.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/doctor_directory_repository.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/repository_errors.dart';
import 'package:godoctor_app/data/repositories/stock_sync_repository.dart';
import 'package:godoctor_app/features/chemist/import/stock_import_screen.dart';
import 'package:godoctor_app/features/chemist/import/stock_table.dart';
import 'package:godoctor_app/features/location/location_picker_screen.dart'
    show geocoderProvider;
import 'package:godoctor_app/features/patient/chemist/pharmacies_screen.dart';
import 'package:godoctor_app/features/patient/screens/order_tracking_screen.dart';
import 'package:godoctor_app/features/patient/visits/visit_widgets.dart';
import 'package:godoctor_app/services/chemist_matching.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes.dart';

final _now = DateTime.now();

model.Order _order(OrderStatus status, {FulfillmentType? how, String? note}) =>
    model.Order(
      id: 'o1',
      patientId: 'p1',
      chemistId: 'ch1',
      status: status,
      totalAmount: 360,
      escrowStatus: status == OrderStatus.fulfilled
          ? EscrowStatus.released
          : EscrowStatus.held,
      fulfillmentType: how ?? FulfillmentType.pickup,
      createdAt: _now.subtract(const Duration(minutes: 30)),
      confirmedAt: status == OrderStatus.placed
          ? null
          : _now.subtract(const Duration(minutes: 20)),
      chemistName: 'Afya Chemist',
      problemNote: note,
      items: const [
        model.OrderItem(
          orderId: 'o1',
          drugId: 'para',
          quantity: 2,
          unitPrice: 180,
          drugName: 'Paracetamol',
        ),
      ],
    );

class _LiveOrders extends OrderRepository {
  _LiveOrders(this.current);

  model.Order current;
  final _changes = StreamController<model.Order?>.broadcast();
  String? confirmed;
  String? disputeNote;

  void push(model.Order o) {
    current = o;
    _changes.add(o);
  }

  @override
  Stream<model.Order?> watchOrder(String orderId) async* {
    yield current;
    yield* _changes.stream;
  }

  @override
  Future<void> patientConfirmReceipt(String orderId) async {
    confirmed = orderId;
    push(_order(OrderStatus.fulfilled));
  }

  @override
  Future<void> flagDisputed(String orderId, {String? note}) async {
    disputeNote = note;
    push(_order(OrderStatus.disputed, note: note));
  }
}

class _Sync extends StockSyncRepository {
  List<({String drugId, int quantity, double price})>? saved;

  @override
  Future<Map<String, DrugMatch?>> matchNames(List<String> names) async => {
    for (final n in names)
      n: n.toLowerCase().startsWith('panadol')
          ? (id: 'para', name: 'Paracetamol 500mg')
          : null,
  };

  @override
  Future<int> importStock(
    List<({String drugId, int quantity, double price})> rows,
  ) async {
    saved = rows;
    return rows.length;
  }
}

class _Directory extends DoctorDirectoryRepository {
  @override
  Future<List<PublicChemist>> listChemists() async => const [
    PublicChemist(
      userId: 'far',
      name: 'Westlands Pharmacy',
      locationName: 'Westlands, Nairobi',
      lat: -1.2676,
      lng: 36.8108,
      medicinesInStock: 40,
    ),
    PublicChemist(
      userId: 'unknown',
      name: 'Mystery Chemist',
      medicinesInStock: 3,
      ordersFilled: 12,
    ),
    PublicChemist(
      userId: 'near',
      name: 'CBD Chemist',
      locationName: 'Moi Avenue, Nairobi',
      lat: -1.2854,
      lng: 36.8182,
      medicinesInStock: 120,
      ordersFilled: 300,
    ),
  ];
}

Future<void> _pump(WidgetTester tester, [int times = 6]) async {
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
      overrides: [currentUserIdProvider.overrideWithValue('p1'), ...overrides],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await _pump(tester);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('stock files', () {
    test('CSV with a header: selling price, quoted names, 1,200', () {
      final t = parseStockTable(
        'Item Name,Cost Price,Selling Price,Qty on hand\r\n'
        '"Panadol, 500mg tabs",3,KES 5,"1,200"\r\n'
        'Amoxil 250mg,8,12,60\r\n',
      );
      expect(t.lines.length, 2);
      expect(t.lines.first.name, 'Panadol, 500mg tabs');
      expect(t.lines.first.price, 5);
      expect(t.lines.first.quantity, 1200);
      expect(t.columns.name, 'Item Name');
      expect(t.columns.price, 'Selling Price');
      expect(t.columns.quantity, 'Qty on hand');
    });

    test('pasted cells without a header: name, qty, price', () {
      final t = parseStockTable('Amoxil 250mg\t60\t12\nBrufen 400\t30\t8.5');
      expect([for (final l in t.lines) l.quantity], [60, 30]);
      expect(t.lines.last.price, 8.5);
      expect(t.columns.name, 'Column 1');
    });

    test('a first line that is data is kept, even if it says "brand"', () {
      final t = parseStockTable('Brand X syrup,10,50\nOther,2,3');
      expect(t.lines.length, 2);
    });

    test('semicolon files with decimal commas', () {
      final t = parseStockTable('Name;Stock;Price\nIbuprofen 200;10;12,50');
      expect(t.lines.single.price, 12.5);
    });

    test('lines without a price or quantity are left out, and said so', () {
      final t = parseStockTable('Name,Qty,Price\nGood,1,2\nNo price,4,\n,3,3');
      expect(t.lines.single.name, 'Good');
      expect(t.skipped, [
        'Line 3 (No price): no price',
        'Line 4: no medicine name',
      ]);
    });

    test('empty text reads as nothing', () {
      expect(parseStockTable('  \n ').lines, isEmpty);
    });
  });

  test('order errors read like people talk', () {
    PostgrestException err(String m) =>
        PostgrestException(message: m, code: 'P0001');
    expect(
      friendlyError(err('out_of_stock: Amoxicillin 500mg')),
      contains('no longer has enough Amoxicillin 500mg'),
    );
    expect(
      friendlyError(err('prescription_required: Amoxicillin')),
      contains('Amoxicillin needs a prescription'),
    );
    expect(
      friendlyError(err('order_not_ready')),
      contains('once the pharmacy has confirmed'),
    );
    expect(friendlyError(err('too_many_keys')), contains('5 active'));
  });

  test('visits: months, friendly dates and where a tap goes', () {
    final now = DateTime(2026, 9, 15, 12);
    final dates = [
      DateTime(2026, 9, 10),
      DateTime(2026, 9, 1),
      DateTime(2026, 8, 20),
      DateTime(2026, 7, 3),
      DateTime(2025, 12, 1),
    ];
    expect(
      [for (final g in groupByMonth(dates, (d) => d, now: now)) g.$1],
      ['This month', 'Last month', 'July', 'December 2025'],
    );
    expect(visitWhen(DateTime(2026, 9, 15, 9, 30), now: now), 'Today, 09:30');
    expect(visitWhen(DateTime(2026, 9, 14, 20), now: now), 'Yesterday');
    expect(visitWhen(DateTime(2026, 9, 12), now: now), '3 days ago');
    expect(visitWhen(DateTime(2026, 8, 1), now: now), '1 Aug');
    expect(visitWhen(DateTime(2025, 12, 1), now: now), '1 Dec 2025');

    final v = Visit.fromMap({
      'consultation_id': 'c9',
      'doctor_name': 'Jane Wanjiru',
      'specialty': 'Paediatrics',
      'status': 'in_progress',
      'mode': 'on_demand',
      'happened_at': '2026-09-15T08:00:00Z',
      'prescriptions': 2,
      'has_summary': false,
    });
    expect(v.isOngoing, isTrue);
    expect(v.route, '/patient/call/c9');
    expect(v.doctorLabel, 'Dr. Jane Wanjiru');
    expect(v.prescriptions, 2);
  });

  test('pharmacies: nearest first, then the rest by orders filled', () async {
    final all = await _Directory().listChemists();
    const cbd = MatchPoint(
      lat: -1.2864,
      lng: 36.8172,
      source: MatchSource.profile,
    );
    expect(
      [for (final r in rankPharmacies(all, cbd)) r.chemist.userId],
      ['near', 'far', 'unknown'],
    );
    expect(
      [
        for (final r in rankPharmacies(all, cbd, query: 'west'))
          r.chemist.userId,
      ],
      ['far'],
    );
  });

  testWidgets('order status moves by itself; confirm receipt releases pay', (
    tester,
  ) async {
    final orders = _LiveOrders(_order(OrderStatus.placed));
    await _host(tester, const OrderTrackingScreen(orderId: 'o1'), [
      orderRepositoryProvider.overrideWithValue(orders),
    ]);
    expect(find.text('Waiting for the pharmacy'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('I\'ve got my medicine'), findsNothing);

    // The pharmacy marks it ready -- no refresh needed.
    orders.push(_order(OrderStatus.ready));
    await _pump(tester);
    expect(find.text('Ready for pickup'), findsWidgets);
    await tester.ensureVisible(find.text('I\'ve got my medicine'));
    await tester.tap(find.text('I\'ve got my medicine'));
    await _pump(tester);
    expect(find.text('Got your medicine?'), findsOneWidget);
    await tester.tap(find.text('Yes, I have it'));
    await _pump(tester, 8);
    expect(orders.confirmed, 'o1');
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Released to the pharmacy'), findsOneWidget);
    expect(find.text('Report a problem'), findsNothing);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('report a problem asks what went wrong and keeps pay held', (
    tester,
  ) async {
    final orders = _LiveOrders(
      _order(OrderStatus.confirmed, how: FulfillmentType.delivery),
    );
    await _host(tester, const OrderTrackingScreen(orderId: 'o1'), [
      orderRepositoryProvider.overrideWithValue(orders),
    ]);
    expect(find.text('Being prepared'), findsOneWidget);
    await tester.ensureVisible(find.text('Report a problem'));
    await tester.tap(find.text('Report a problem'));
    await _pump(tester);
    await tester.tap(find.text('Taking too long'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Two hours already');
    await tester.tap(find.text('Report'));
    await _pump(tester, 8);
    expect(orders.disputeNote, 'Taking too long: Two hours already');
    expect(find.text('Problem reported'), findsOneWidget);
    expect(find.textContaining('Two hours already'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('import stock: paste, check the matches, save', (tester) async {
    final sync = _Sync();
    await _host(tester, const StockImportScreen(), [
      stockSyncRepositoryProvider.overrideWithValue(sync),
    ]);
    await tester.ensureVisible(find.text('Paste from a spreadsheet'));
    await tester.tap(find.text('Paste from a spreadsheet'));
    await _pump(tester);
    await tester.enterText(
      find.byType(TextField),
      'Name\tQty\tSelling price\nPanadol 500mg\t240\t5\nMystery syrup\t3\t9',
    );
    await tester.tap(find.text('Read it'));
    await _pump(tester, 8);

    expect(find.text('We read 2 medicines'), findsOneWidget);
    expect(find.text('Matched (1)'), findsOneWidget);
    expect(find.text('Not found (1)'), findsOneWidget);
    expect(find.text('→ Paracetamol 500mg'), findsOneWidget);
    await tester.tap(find.text('Not found (1)'));
    await tester.pump();
    expect(find.text('Mystery syrup'), findsOneWidget);

    await tester.tap(find.text('Save 1 medicine to my stock'));
    await _pump(tester, 10);
    expect(sync.saved, [(drugId: 'para', quantity: 240, price: 5.0)]);
    expect(find.text('1 medicine saved'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('pharmacies near the patient, with profiles a tap away', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _host(tester, const PharmaciesScreen(), [
      currentPatientProfileProvider.overrideWith(
        (ref) async => const PatientProfile(
          userId: 'p1',
          name: 'Amina',
          locationLat: -1.2864,
          locationLng: 36.8172,
          locationName: 'Nairobi CBD, Nairobi, Kenya',
        ),
      ),
      doctorDirectoryRepositoryProvider.overrideWithValue(_Directory()),
      geocoderProvider.overrideWithValue(FakeGeocoder()),
    ]);
    if (find.text('Not now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await _pump(tester);
    }
    expect(find.text('NEAREST'), findsOneWidget);
    final near = tester.getTopLeft(find.text('CBD Chemist')).dy;
    final far = tester.getTopLeft(find.text('Westlands Pharmacy')).dy;
    expect(near, lessThan(far));
    expect(find.text('300 orders filled'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'westlands');
    await _pump(tester, 3);
    expect(find.text('CBD Chemist'), findsNothing);
    expect(find.text('Westlands Pharmacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}
