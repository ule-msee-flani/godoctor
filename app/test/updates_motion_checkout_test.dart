// In-app updates, friendly errors, the motion kit, and the medicine
// checkout (prescription picked for you, M-Pesa prompt, confirmation).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/motion.dart';
import 'package:godoctor_app/data/models/drug.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/models/patient_profile.dart';
import 'package:godoctor_app/data/models/prescription.dart';
import 'package:godoctor_app/data/providers/auth_providers.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/order_repository.dart';
import 'package:godoctor_app/data/repositories/prescription_repository.dart';
import 'package:godoctor_app/data/repositories/repository_errors.dart';
import 'package:godoctor_app/features/patient/screens/checkout_screen.dart';
import 'package:godoctor_app/features/update/update_sheet.dart';
import 'package:godoctor_app/services/app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes.dart';

const _amox = Drug(
  id: 'amox',
  genericName: 'Amoxicillin',
  brandNames: ['Amoxil'],
  form: 'capsule',
  requiresPrescription: true,
);

final _now = DateTime.now();

class _Prescriptions extends PrescriptionRepository {
  @override
  Future<List<Prescription>> fetchForPatient(String patientId) async => [
    Prescription(
      id: 'rx-other',
      patientId: 'p1',
      source: PrescriptionSource.app,
      issuedAt: _now.subtract(const Duration(days: 2)),
      validUntil: _now.add(const Duration(days: 20)),
      items: const [
        PrescriptionItem(
          prescriptionId: 'rx-other',
          drugId: 'para',
          drugName: 'Paracetamol',
          quantity: 10,
        ),
      ],
    ),
    Prescription(
      id: 'rx-amox',
      patientId: 'p1',
      source: PrescriptionSource.app,
      issuedAt: _now.subtract(const Duration(days: 1)),
      validUntil: _now.add(const Duration(days: 20)),
      items: const [
        PrescriptionItem(
          prescriptionId: 'rx-amox',
          drugId: 'amox',
          drugName: 'Amoxicillin',
          quantity: 15,
        ),
      ],
    ),
  ];
}

class _Orders extends OrderRepository {
  String? prescriptionId;
  String? fulfillment;
  int? quantity;

  @override
  Future<String> placeOrder({
    required String chemistId,
    String? prescriptionId,
    required List<CartLine> lines,
    required String fulfillmentType,
  }) async {
    this.prescriptionId = prescriptionId;
    fulfillment = fulfillmentType;
    quantity = lines.single.quantity;
    return 'order-9';
  }
}

void main() {
  group('in-app updates', () {
    test('reads the published version file', () {
      final r = AppRelease.tryParse(
        '{"version":"1.2.0","build":7,"size":57671680,'
        '"apk":"https://github.com/x/y/releases/download/v1.2.0/GoDoctor-1.2.0.apk",'
        '"notes":["Faster checkout",""," Calmer animations "]}',
      )!;
      expect(r.version, '1.2.0');
      expect(r.build, 7);
      expect(r.sizeLabel, '55 MB');
      expect(r.notes, ['Faster checkout', 'Calmer animations']);
      expect(isNewerRelease(r, 6), isTrue);
      expect(isNewerRelease(r, 7), isFalse);
      expect(isNewerRelease(null, 1), isFalse);
    });

    test('ignores anything malformed or not https', () {
      expect(AppRelease.tryParse('not json'), isNull);
      expect(AppRelease.tryParse('{"version":"1"}'), isNull);
      expect(
        AppRelease.tryParse('{"build":3,"apk":"http://evil/app.apk"}'),
        isNull,
      );
    });

    testWidgets('the prompt shows what\'s new; Later snoozes that version', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      const release = AppRelease(
        version: '1.2.0',
        build: 9,
        apkUrl: 'https://example.com/GoDoctor-1.2.0.apk',
        sizeBytes: 50 * 1024 * 1024,
        notes: ['Faster checkout'],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.patientTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showUpdateSheet(
                  context,
                  release,
                  installedVersion: '1.1.0',
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('A new version of GoDoctor is ready'), findsOneWidget);
      expect(find.textContaining('you have 1.1.0'), findsOneWidget);
      expect(find.text('Faster checkout'), findsOneWidget);
      expect(find.text('Update now'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Update now'), findsNothing);
      expect(await UpdateSnooze.isSnoozed(release), isTrue);
    });
  });

  group('errors people see', () {
    test('database and API internals are never shown', () {
      expect(
        friendlyError(
          const PostgrestException(
            message:
                "Could not find a relationship between 'chemist_inventory' and 'chemist_profiles' in the schema cache",
            code: 'PGRST200',
          ),
        ),
        'Something went wrong on our side. Please try again in a moment.',
      );
      expect(
        friendlyError(
          const PostgrestException(
            message:
                'column "status" is of type doctor_status but expression is of type text',
            code: '42804',
          ),
        ),
        startsWith('Something went wrong on our side'),
      );
    });

    test('our own short messages and network problems read plainly', () {
      expect(
        friendlyError(
          const PostgrestException(
            message: 'doctor is not yet verified',
            code: 'P0001',
          ),
        ),
        'doctor is not yet verified',
      );
      expect(
        friendlyError(Exception('SocketException: Failed host lookup')),
        startsWith('No internet connection'),
      );
    });
  });

  group('motion', () {
    Future<double> bellAngle(WidgetTester tester, {required bool still}) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: still),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: Ringing(
              active: true,
              child: SizedBox(width: 20, height: 20),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final t = tester.widget<Transform>(
        find.descendant(
          of: find.byType(Ringing),
          matching: find.byType(Transform),
        ),
      );
      final angle = t.transform.getRotation().entry(1, 0).abs();
      await tester.pumpWidget(const SizedBox());
      return angle;
    }

    testWidgets('the bell rings while something is waiting', (tester) async {
      expect(await bellAngle(tester, still: false), greaterThan(0.01));
    });

    testWidgets('and stays still when the phone asks for less motion', (
      tester,
    ) async {
      expect(await bellAngle(tester, still: true), lessThan(0.0001));
    });

    testWidgets('badge counts pop and cap at 9+', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PopBadge(count: 12, child: Icon(Icons.chat))),
      );
      await tester.pumpAndSettle();
      expect(find.text('9+'), findsOneWidget);
    });

    testWidgets('lists fade in', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FadeSlideIn(index: 2, child: Text('row'))),
      );
      final fade = tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.text('row'),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade.opacity.value, 0);
      // Starts after its place in the cascade (index 2).
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(fade.opacity.value, 1);
    });
  });

  testWidgets('checkout: prescription picked for you, M-Pesa, confirmed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final orders = _Orders();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('p1'),
          currentPatientProfileProvider.overrideWith(
            (ref) async => const PatientProfile(
              userId: 'p1',
              name: 'Amina Hassan',
              locationName: 'Ruiru, Kiambu',
            ),
          ),
          prescriptionRepositoryProvider.overrideWithValue(_Prescriptions()),
          orderRepositoryProvider.overrideWithValue(orders),
          billingRepositoryProvider.overrideWithValue(FakeBilling()),
          authRepositoryProvider.overrideWithValue(FakeAuth()),
        ],
        child: MaterialApp(
          theme: AppTheme.patientTheme,
          home: CheckoutScreen(
            item: ChemistInventoryItem(
              chemistId: 'ch1',
              drugId: 'amox',
              quantity: 30,
              price: 120,
              lastUpdatedAt: _now,
              drug: _amox,
              chemistName: 'Afya Chemist',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prescription needed'), findsOneWidget);
    expect(find.text('Includes Amoxicillin'), findsOneWidget);
    expect(find.text('Doesn\'t include Amoxicillin'), findsOneWidget);
    expect(find.text('0712 345 678'), findsOneWidget, reason: 'saved M-Pesa');

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.text('Delivery'));
    await tester.pump();
    expect(find.text('Pay KES 240'), findsOneWidget);

    await tester.tap(find.text('Pay KES 240'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Check your phone'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Order placed'), findsOneWidget);
    expect(
      orders.prescriptionId,
      'rx-amox',
      reason: 'the one with this medicine',
    );
    expect(orders.fulfillment, 'delivery');
    expect(orders.quantity, 2);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
