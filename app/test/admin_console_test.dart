// The super-admin console: every page renders inside the shell (desktop
// sidebar and phone drawer) with realistic fake data, and the main admin
// actions call the backend with the right arguments.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/chemist_profile.dart';
import 'package:godoctor_app/data/models/doctor_profile.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/data/repositories/admin_repository.dart';
import 'package:godoctor_app/data/repositories/profile_repository.dart';
import 'package:godoctor_app/features/admin/admin_shell.dart';
import 'package:godoctor_app/features/admin/screens/admin_activity_screen.dart';
import 'package:godoctor_app/features/admin/screens/admin_database_screen.dart';
import 'package:godoctor_app/features/admin/screens/admin_engage_screens.dart';
import 'package:godoctor_app/features/admin/screens/admin_overview_screen.dart';
import 'package:godoctor_app/features/admin/screens/admin_records_screens.dart';
import 'package:godoctor_app/features/admin/screens/admin_users_screen.dart';
import 'package:godoctor_app/features/admin/screens/admin_verification_screen.dart';
import 'package:godoctor_app/features/admin/widgets/admin_ui.dart';

import 'support/fakes.dart';

final _now = DateTime.now().toUtc();
String _ago(int minutes) =>
    _now.subtract(Duration(minutes: minutes)).toIso8601String();

class FakeAdmin extends AdminRepository {
  final List<({String? role, String? search})> userQueries = [];
  ({String id, String status})? statusChange;
  ({String? role, String title})? broadcasted;
  ({String id, String status})? orderChange;
  String? cancelled;

  @override
  Future<Map<String, dynamic>> overview({int days = 30}) async => {
    'days': days,
    'users_total': 142,
    'users_by_role': {'patient': 120, 'doctor': 14, 'chemist': 7, 'admin': 1},
    'users_new': 31,
    'users_new_prev': 22,
    'users_suspended': 1,
    'online_now': 9,
    'sessions_active': 40,
    'doctors_available': 5,
    'doctors_busy': 2,
    'consults_live': 2,
    'consults_awaiting_payment': 1,
    'consults': 64,
    'consults_prev': 70,
    'consults_by_status': {'completed': 50, 'cancelled': 6, 'in_progress': 2},
    'revenue': 51200,
    'revenue_prev': 40100,
    'revenue_consults': 44000,
    'revenue_orders': 7200,
    'orders': 18,
    'orders_prev': 18,
    'orders_by_status': {'fulfilled': 12, 'ready': 3, 'placed': 3},
    'prescriptions': 40,
    'pending_doctors': 3,
    'pending_chemists': 0,
    'tickets_open': 2,
    'rating_avg': 4.6,
    'rating_count': 25,
    'writes_24h': 812,
    'db_size_bytes': 13 * 1024 * 1024,
    'series': [
      for (var i = days - 1; i >= 0; i--)
        {
          'day': _now
              .subtract(Duration(days: i))
              .toIso8601String()
              .substring(0, 10),
          'signups': (i * 7) % 5,
          'consults': (i * 3) % 6,
          'orders': i % 3,
          'revenue': ((i * 13) % 7) * 800,
          'writes': 20 + (i * 11) % 40,
        },
    ],
  };

  @override
  Future<AdminRows> users({
    String? search,
    String? role,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    userQueries.add((role: role, search: search));
    return AdminRows([
      {
        'id': 'u1',
        'name': 'Amina Hassan',
        'email': 'amina@example.com',
        'role': 'patient',
        'status': 'active',
        'verified': null,
        'created_at': _ago(60 * 24 * 3),
        'last_seen_at': _ago(1),
        'last_sign_in_at': _ago(30),
        'total_count': 2,
      },
      {
        'id': 'u2',
        'name': 'Dr Jane Wanjiru',
        'email': 'jane@example.com',
        'role': 'doctor',
        'status': 'suspended',
        'verified': true,
        'created_at': _ago(60 * 24 * 9),
        'last_seen_at': null,
        'last_sign_in_at': _ago(60 * 24),
        'total_count': 2,
      },
    ], 2);
  }

  @override
  Future<Map<String, dynamic>?> userDetail(String userId) async => {
    'user': {
      'id': userId,
      'name': 'Amina Hassan',
      'email': 'amina@example.com',
      'role': 'patient',
      'status': 'active',
      'created_at': _ago(60 * 24 * 3),
      'last_seen_at': _ago(1),
    },
    'auth': {'last_sign_in_at': _ago(30), 'email_confirmed_at': _ago(9000)},
    'profile': {
      'user_id': userId,
      'name': 'Amina Hassan',
      'allergies': 'Penicillin',
      'location_name': 'Ruiru, Kiambu, Kenya',
    },
    'stats': {
      'consultations_as_patient': 4,
      'orders_placed': 2,
      'spent': 3400,
      'writes_30d': 18,
    },
    'sessions': [
      {
        'created_at': _ago(300),
        'last_active': _ago(2),
        'user_agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit Chrome/128 Mobile Safari',
        'ip': '41.90.1.2',
      },
    ],
    'consultations': [
      {
        'id': 'c1',
        'created_at': _ago(500),
        'status': 'completed',
        'specialty_requested': 'ENT',
        'other': 'Dr Jane Wanjiru',
      },
    ],
    'orders': [
      {
        'id': 'o1',
        'created_at': _ago(400),
        'status': 'fulfilled',
        'total_amount': 450,
        'other': 'Afya Chemist',
      },
    ],
    'activity': [
      {
        'id': 9,
        'at': _ago(3),
        'table_name': 'patient_profiles',
        'op': 'UPDATE',
        'row_id': userId,
        'changed': ['allergies'],
      },
    ],
  };

  @override
  Future<void> setUserStatus(String userId, String status) async =>
      statusChange = (id: userId, status: status);

  @override
  Future<AdminRows> consultations({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows([
    {
      'id': 'c1-aaaa-bbbb',
      'created_at': _ago(20),
      'status': 'in_progress',
      'mode': 'on_demand',
      'specialty': 'ENT',
      'patient_id': 'u1',
      'patient_name': 'Amina Hassan',
      'doctor_id': 'u2',
      'doctor_name': 'Dr Jane Wanjiru',
      'fee': 800,
      'paid': true,
      'started_at': _ago(15),
      'ended_at': null,
      'prescriptions': 1,
      'family': 1,
    },
  ], 1);

  @override
  Future<void> cancelConsultation(String id) async => cancelled = id;

  @override
  Future<AdminRows> orders({
    String? search,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows([
    {
      'id': 'o1-aaaa-bbbb',
      'created_at': _ago(40),
      'status': 'placed',
      'escrow': 'held',
      'fulfillment': 'pickup',
      'total': 450,
      'patient_id': 'u1',
      'patient_name': 'Amina Hassan',
      'chemist_id': 'u3',
      'chemist_name': 'Afya Chemist',
      'items': 2,
      'has_prescription': true,
    },
  ], 1);

  @override
  Future<void> setOrderStatus(String orderId, String status) async =>
      orderChange = (id: orderId, status: status);

  @override
  Future<AdminRows> payments({
    String? status,
    int limit = 50,
    int offset = 0,
  }) async => AdminRows([
    {
      'id': 'p1-aaaa',
      'created_at': _ago(40),
      'amount': 800,
      'provider': 'mpesa',
      'status': 'succeeded',
      'is_simulated': true,
      'kind': 'consultation',
      'payer_name': 'Amina Hassan',
      'reference': 'c1-aaaa-bbbb',
    },
  ], 1);

  @override
  Future<List<Map<String, dynamic>>> sessions({int limit = 100}) async => [
    {
      'user_id': 'u1',
      'name': 'Amina Hassan',
      'role': 'patient',
      'created_at': _ago(300),
      'last_active': _ago(2),
      'user_agent': 'Dart/3.12 (dart:io)',
      'ip': '41.90.1.2',
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> activity({
    String? table,
    String? op,
    String? actorId,
    int limit = 100,
    int? before,
  }) async => [
    for (final (i, o, t) in [
      (3, 'INSERT', 'consultations'),
      (2, 'UPDATE', 'patient_profiles'),
      (1, 'DELETE', 'payment_methods'),
    ])
      if (op == null || op == o)
        {
          'id': i,
          'at': _ago(i),
          'actor_id': 'u1',
          'actor_name': 'Amina Hassan',
          'actor_role': 'patient',
          'table_name': t,
          'op': o,
          'row_id': 'row-$i-xxxxxxxx',
          'changed': o == 'UPDATE' ? ['allergies'] : null,
        },
  ];

  @override
  Stream<List<Map<String, dynamic>>> watchActivity() => Stream.value(const []);

  @override
  Future<Map<String, dynamic>> dbStats() async => {
    'db_size_bytes': 13 * 1024 * 1024,
    'postgres_version': '17.4',
    'connections': {'active': 2, 'idle': 9},
    'cache_hit_ratio': 0.9981,
    'tables': [
      for (final (name, rows) in [
        ('drugs', 90),
        ('users', 142),
        ('audit_log', 4200),
      ])
        {
          'name': name,
          'rows': rows,
          'size_bytes': rows * 900,
          'inserts': rows,
          'updates': rows ~/ 2,
          'deletes': 3,
          'seq_scans': 12,
          'index_scans': 4000,
        },
    ],
    'top_queries': [
      {
        'query': 'select * from public.drugs order by generic_name limit \$1',
        'calls': 420,
        'total_ms': 910.2,
        'mean_ms': 2.17,
        'rows': 37800,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> tableRows(
    String table, {
    int limit = 50,
    int offset = 0,
  }) async => {
    'columns': [
      {'name': 'id', 'type': 'uuid'},
      {'name': 'generic_name', 'type': 'text'},
      {'name': 'requires_prescription', 'type': 'boolean'},
    ],
    'rows': [
      {
        'id': 'd1',
        'generic_name': 'Paracetamol',
        'requires_prescription': false,
      },
      {
        'id': 'd2',
        'generic_name': 'Amoxicillin',
        'requires_prescription': true,
      },
    ],
    'total': 2,
  };

  @override
  Future<int> broadcast({
    String? role,
    required String title,
    required String body,
  }) async {
    broadcasted = (role: role, title: title);
    return 120;
  }
}

class _Profiles extends ProfileRepository {
  @override
  Future<List<DoctorProfile>> fetchPendingDoctors() async => const [
    DoctorProfile(
      userId: 'd9',
      name: 'Dr Pending',
      specialties: ['ENT'],
      licenseNumber: 'KMPDC-9',
      licenseVerified: false,
      verificationDocuments: ['a.pdf'],
      status: DoctorStatus.offline,
      ratingAvg: 0,
    ),
  ];
  @override
  Future<List<ChemistProfile>> fetchPendingChemists() async => const [];
  @override
  String? avatarUrl(String? path) => null;
}

Future<void> _render(
  WidgetTester tester,
  String location,
  Widget page, {
  Size size = const Size(1366, 900),
  FakeAdmin? admin,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminRepositoryProvider.overrideWithValue(admin ?? FakeAdmin()),
        profileRepositoryProvider.overrideWithValue(_Profiles()),
        supportRepositoryProvider.overrideWithValue(FakeSupport()),
        authRepositoryProvider.overrideWithValue(FakeAuth()),
      ],
      child: MaterialApp(
        theme: AppTheme.patientTheme,
        home: Theme(
          data: AppTheme.professionalTheme,
          child: AdminShell(location: location, child: page),
        ),
      ),
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
  final pages = <String, (String, Widget)>{
    'overview': ('/admin', const AdminOverviewScreen()),
    'live traffic': ('/admin/activity', const AdminActivityScreen()),
    'database': ('/admin/database', const AdminDatabaseScreen()),
    'table browser': (
      '/admin/database/drugs',
      const AdminTableBrowserScreen(table: 'drugs'),
    ),
    'users': ('/admin/users', const AdminUsersScreen()),
    'user detail': (
      '/admin/users/u1',
      const AdminUserDetailScreen(userId: 'u1'),
    ),
    'verification': ('/admin/verification', const AdminVerificationScreen()),
    'consultations': ('/admin/consultations', const AdminConsultationsScreen()),
    'orders': ('/admin/orders', const AdminOrdersScreen()),
    'payments': ('/admin/payments', const AdminPaymentsScreen()),
    'support': ('/admin/support', const AdminSupportScreen()),
    'announcements': ('/admin/broadcast', const AdminBroadcastScreen()),
  };

  for (final entry in pages.entries) {
    for (final (label, size) in [
      ('desktop', const Size(1366, 900)),
      ('phone', const Size(412, 915)),
    ]) {
      testWidgets('${entry.key} renders ($label)', (tester) async {
        final (location, page) = entry.value;
        await _render(tester, location, page, size: size);
        expect(tester.takeException(), isNull);
        await _close(tester);
      });
    }
  }

  testWidgets('desktop shows the sidebar with every section', (tester) async {
    await _render(tester, '/admin', const AdminOverviewScreen());
    for (final label in [
      'Overview',
      'Live traffic',
      'Database',
      'Users',
      'Verification',
      'Consultations',
      'Orders',
      'Payments',
      'Support',
      'Announcements',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    await _close(tester);
  });

  testWidgets('overview: KPIs, deltas and chart table view', (tester) async {
    await _render(tester, '/admin', const AdminOverviewScreen());
    expect(find.text('KES 51.2K'), findsOneWidget);
    expect(
      find.text('28% vs previous'),
      findsOneWidget,
    ); // revenue 40.1K -> 51.2K
    expect(find.text('no change'), findsOneWidget); // orders 18 -> 18
    await tester.scrollUntilVisible(
      find.text('Patients'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AdminPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Patients'), findsOneWidget);
    await tester.tap(find.byTooltip('Show as table').first);
    await _settle(tester);
    expect(find.byTooltip('Show chart'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _close(tester);
  });

  testWidgets('users: role filter is sent to the backend', (tester) async {
    final admin = FakeAdmin();
    await _render(
      tester,
      '/admin/users',
      const AdminUsersScreen(),
      admin: admin,
    );
    await tester.tap(find.text('Doctors'));
    await _settle(tester);
    expect(admin.userQueries.last.role, 'doctor');
    await _close(tester);
  });

  testWidgets('user detail: suspending asks first, then calls the backend', (
    tester,
  ) async {
    final admin = FakeAdmin();
    await _render(
      tester,
      '/admin/users/u1',
      const AdminUserDetailScreen(userId: 'u1'),
      admin: admin,
    );
    expect(find.text('Chrome on Android'), findsOneWidget);
    await tester.tap(find.text('Suspend'));
    await _settle(tester);
    expect(find.text('Suspend Amina Hassan?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Suspend').last);
    await _settle(tester);
    expect(admin.statusChange, (id: 'u1', status: 'suspended'));
    await _close(tester);
  });

  testWidgets('consultations: an admin can cancel a live one', (tester) async {
    final admin = FakeAdmin();
    await _render(
      tester,
      '/admin/consultations',
      const AdminConsultationsScreen(),
      admin: admin,
    );
    await tester.tap(find.text('Amina Hassan').first);
    await _settle(tester);
    await tester.tap(find.text('Cancel consultation'));
    await _settle(tester);
    expect(admin.cancelled, 'c1-aaaa-bbbb');
    await _close(tester);
  });

  testWidgets('orders: status override', (tester) async {
    final admin = FakeAdmin();
    await _render(
      tester,
      '/admin/orders',
      const AdminOrdersScreen(),
      admin: admin,
    );
    await tester.tap(find.text('Afya Chemist').first);
    await _settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await _settle(tester);
    await tester.tap(find.text('Refunded').last);
    await _settle(tester);
    await tester.tap(find.text('Save status'));
    await _settle(tester);
    expect(admin.orderChange, (id: 'o1-aaaa-bbbb', status: 'refunded'));
    await _close(tester);
  });

  testWidgets('live traffic filters by operation', (tester) async {
    await _render(tester, '/admin/activity', const AdminActivityScreen());
    expect(find.text('patient_profiles'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Deletes'));
    await _settle(tester);
    expect(find.text('patient_profiles'), findsNothing);
    expect(find.text('payment_methods'), findsWidgets);
    await _close(tester);
  });

  testWidgets('announcement goes to the chosen group', (tester) async {
    final admin = FakeAdmin();
    await _render(
      tester,
      '/admin/broadcast',
      const AdminBroadcastScreen(),
      admin: admin,
    );
    await tester.tap(find.text('Doctors'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Clinic hours update',
    );
    await tester.pump();
    await tester.tap(find.text('Send announcement'));
    await _settle(tester);
    await tester.tap(find.text('Send'));
    await _settle(tester);
    expect(admin.broadcasted, (role: 'doctor', title: 'Clinic hours update'));
    expect(find.text('Announcement sent to 120 people'), findsOneWidget);
    await _close(tester);
  });

  test('device descriptions', () {
    expect(describeDevice('Dart/3.12 (dart:io)'), 'GoDoctor app');
    expect(
      describeDevice('Mozilla/5.0 (Windows NT 10.0) Chrome/128 Safari/537'),
      'Chrome on Windows',
    );
    expect(describeDevice(null), 'Unknown device');
  });
}
