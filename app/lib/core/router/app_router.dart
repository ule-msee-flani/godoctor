import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/drug.dart';
import '../../data/models/enums.dart';
import '../../data/models/support.dart';
import '../../features/chat/chat_prescribe_screen.dart';
import '../../features/chat/chat_providers.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/chats_screen.dart';
import '../../features/chemist/import/connect_system_screen.dart';
import '../../features/chemist/import/stock_import_screen.dart';
import '../../features/chemist/screens/chemist_account_screen.dart';
import '../../features/location/location_picker_screen.dart';
import '../../features/notifications/notification_settings_screen.dart';
import '../../features/patient/family/family_session_screen.dart';
import '../../features/patient/health/health_story_screen.dart';
import '../../features/patient/profile/account_screen.dart';
import '../../features/patient/profile/billing_screen.dart';
import '../../features/patient/profile/family_screen.dart';
import '../../features/patient/profile/health_screen.dart';
import '../../features/patient/profile/location_screen.dart';
import '../../features/support/new_ticket_screen.dart';
import '../../features/support/support_screen.dart';
import '../../features/support/ticket_screen.dart';
import '../../services/geocoding.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/admin/screens/admin_activity_screen.dart';
import '../../features/admin/screens/admin_database_screen.dart';
import '../../features/admin/screens/admin_engage_screens.dart';
import '../../features/admin/screens/admin_overview_screen.dart';
import '../../features/admin/screens/admin_records_screens.dart';
import '../../features/admin/screens/admin_users_screen.dart';
import '../../features/admin/screens/admin_verification_screen.dart';
import '../../features/auth/screens/suspended_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/role_select_screen.dart';
import '../../features/chemist/screens/chemist_inventory_screen.dart';
import '../../features/chemist/screens/chemist_onboarding_screen.dart';
import '../../features/chemist/screens/chemist_orders_screen.dart';
import '../../features/doctor/screens/doctor_call_screen.dart';
import '../../features/doctor/screens/doctor_dashboard_screen.dart';
import '../../features/doctor/screens/doctor_history_screen.dart';
import '../../features/doctor/screens/doctor_medicines_screen.dart';
import '../../features/doctor/screens/doctor_onboarding_screen.dart';
import '../../features/doctor/screens/doctor_profile_edit_screen.dart';
import '../../features/doctor/screens/doctor_schedule_screen.dart';
import '../../features/patient/screens/checkout_screen.dart';
import '../../features/patient/screens/chemist_select_screen.dart';
import '../../features/patient/screens/consultation_history_screen.dart';
import '../../features/patient/screens/consultation_waiting_screen.dart';
import '../../features/patient/screens/intake_form_screen.dart';
import '../../features/patient/screens/medicine_search_screen.dart';
import '../../features/patient/screens/order_history_screen.dart';
import '../../features/patient/screens/order_tracking_screen.dart';
import '../../features/patient/screens/patient_call_screen.dart';
import '../../features/patient/consult/available_doctors_screen.dart';
import '../../features/patient/consult/consult_pay_screen.dart';
import '../../features/patient/screens/appointment_detail_screen.dart';
import '../../features/patient/screens/book_appointment_screen.dart';
import '../../features/patient/screens/doctor_profile_screen.dart';
import '../../features/patient/screens/doctors_screen.dart';
import '../../features/patient/screens/notifications_screen.dart';
import '../../features/patient/screens/patient_home_screen.dart';
import '../../features/patient/screens/patient_shell.dart';
import '../../features/patient/screens/profile_screen.dart';
import '../../features/patient/screens/prescriptions_screen.dart';
import '../../features/patient/screens/upload_prescription_screen.dart';
import '../../features/patient/specialties/specialty_registry.dart';
import '../../features/patient/visit/visit_summary_screen.dart';
import '../../features/prescription/prescription_order_screen.dart';
import '../../features/prescription/prescription_view_screen.dart';
import '../../features/patient/chemist/chemist_profile_screen.dart';
import '../../features/patient/chemist/pharmacies_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/exit_guard.dart';
import '../widgets/pending_verification_view.dart';
import '../widgets/role_shell.dart';
import '../../features/chemist/screens/chemist_dashboard_screen.dart';
import '../../features/patient/health/well_guide.dart';
import '../../features/onboarding/welcome_path_screen.dart';

/// A screen with nothing to go back to: back asks before leaving the app.
Widget _top(Widget child) => ExitGuard(child: child);

/// Wraps professional (doctor/chemist/admin) screens in the denser desktop
/// theme -- see PROJECT_SPEC.md "Notes on styling/UX". The rest of the app
/// (patient-facing) uses the mobile-first theme set as MaterialApp's default.
Widget _pro(Widget child) =>
    Theme(data: AppTheme.professionalTheme, child: child);

/// Single router for all three roles: after login, [_redirect] sends the
/// user into the `/patient`, `/doctor`, `/chemist`, or `/admin` branch based
/// on their `public.users.role` and verification flags. See PROJECT_SPEC.md
/// "one app, one router" decision.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-run the redirect when the signed-in user or their account row
  // changes. Listening to the providers the redirect reads (rather than the
  // raw auth stream) means they're already up to date when it runs, so a
  // single tap on "Log in" is enough.
  final refresh = ValueNotifier<int>(0);
  ref.listen(currentUserIdProvider, (_, _) => refresh.value++);
  ref.listen(currentAppUserProvider, (_, next) {
    if (!next.isLoading) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      GoRoute(path: '/auth', builder: (_, _) => const RoleSelectScreen()),
      GoRoute(
        path: '/auth/login/:role',
        builder: (context, state) => LoginScreen(
          role: enumFromDb(
            UserRole.values,
            state.pathParameters['role'],
            UserRole.patient,
          ),
        ),
      ),

      // --- Patient ---
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            PatientShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient',
                builder: (_, _) => const PatientHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/doctors',
                builder: (context, state) => DoctorsScreen(
                  initialSpecialty: state.uri.queryParameters['specialty'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/chats',
                builder: (_, _) => const ChatsScreen(doctor: false),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/health',
                builder: (_, state) => HealthStoryScreen(
                  initialTab: state.uri.queryParameters['tab'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patient/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Old links (notifications sent before the Health tab existed).
      GoRoute(path: '/patient/activity', redirect: (_, _) => '/patient/health'),
      GoRoute(
        path: '/patient/chat/:id',
        builder: (context, state) => ChatScreen(
          consultationId: state.pathParameters['id']!,
          doctor: false,
        ),
      ),
      GoRoute(
        path: '/patient/visit/:id',
        builder: (context, state) =>
            VisitSummaryScreen(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/intake',
        builder: (context, state) => IntakeFormScreen(
          initialSpecialty: state.uri.queryParameters['specialty'],
          initialSymptoms: state.uri.queryParameters['symptoms'],
        ),
      ),
      GoRoute(
        path: '/patient/consult/doctors',
        pageBuilder: (_, state) =>
            _quiet(state, const AvailableDoctorsScreen()),
      ),
      GoRoute(
        path: '/patient/consult/:id/pay',
        builder: (context, state) =>
            ConsultPayScreen(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/specialty/:slug',
        builder: (context, state) =>
            buildSpecialtyPage(context, state.pathParameters['slug']!) ??
            const Scaffold(
              body: Center(child: Text('That specialty page does not exist.')),
            ),
      ),
      GoRoute(
        path: '/patient/doctor/:id',
        builder: (context, state) => DoctorProfileScreen(
          doctorId: state.pathParameters['id']!,
          seeNow: state.uri.queryParameters['see'] == 'now',
        ),
      ),
      GoRoute(
        path: '/patient/book/:doctorId',
        builder: (context, state) => BookAppointmentScreen(
          doctorId: state.pathParameters['doctorId']!,
          rescheduleId: state.uri.queryParameters['reschedule'],
        ),
      ),
      GoRoute(
        path: '/patient/appointment/:id',
        builder: (context, state) => AppointmentDetailScreen(
          consultationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patient/profile/account',
        builder: (_, _) => const AccountScreen(),
      ),
      GoRoute(
        path: '/patient/profile/health',
        builder: (_, _) => const HealthDetailsScreen(),
      ),
      GoRoute(
        path: '/patient/profile/location',
        builder: (_, _) => const PatientLocationScreen(),
      ),
      GoRoute(
        path: '/patient/profile/family',
        builder: (_, _) => const FamilyScreen(),
      ),
      GoRoute(
        path: '/patient/profile/billing',
        builder: (_, _) => const BillingScreen(),
      ),
      GoRoute(
        path: '/patient/family-session/:id',
        builder: (context, state) =>
            FamilySessionScreen(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/notifications',
        pageBuilder: (_, state) => _quiet(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/patient/waiting/:id',
        builder: (context, state) => ConsultationWaitingScreen(
          consultationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/patient/call/:id',
        builder: (context, state) =>
            PatientCallScreen(consultationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/prescriptions',
        pageBuilder: (_, state) => _quiet(state, const PrescriptionsScreen()),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WelcomePathScreen(),
          transitionsBuilder: (context, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),
      GoRoute(
        path: '/patient/well-guide',
        builder: (context, state) => const WellGuideScreen(),
      ),
      GoRoute(
        path: '/patient/pharmacies',
        builder: (context, state) => const PharmaciesScreen(),
      ),
      GoRoute(
        path: '/patient/chemist/:id',
        builder: (context, state) => ChemistProfileScreen(
          chemistId: state.pathParameters['id']!,
          item: state.extra as ChemistInventoryItem?,
        ),
      ),
      GoRoute(
        path: '/patient/prescription/:id',
        builder: (context, state) =>
            PrescriptionViewScreen(prescriptionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/prescription/:id/order',
        builder: (context, state) => PrescriptionOrderScreen(
          prescriptionId: state.pathParameters['id']!,
          initialChemistId: state.uri.queryParameters['chemist'],
        ),
      ),
      GoRoute(
        path: '/patient/prescriptions/upload',
        builder: (_, _) => const UploadPrescriptionScreen(),
      ),
      GoRoute(
        path: '/patient/medicine-search',
        pageBuilder: (_, state) => _quiet(state, const MedicineSearchScreen()),
      ),
      GoRoute(
        path: '/patient/chemist-select/:drugId',
        pageBuilder: (context, state) => _quiet(
          state,
          ChemistSelectScreen(drugId: state.pathParameters['drugId']!),
        ),
      ),
      GoRoute(
        path: '/patient/checkout',
        builder: (context, state) =>
            CheckoutScreen(item: state.extra as ChemistInventoryItem),
      ),
      GoRoute(
        path: '/patient/order/:id',
        builder: (context, state) =>
            OrderTrackingScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/patient/order-history',
        pageBuilder: (_, state) => _quiet(state, const OrderHistoryScreen()),
      ),
      GoRoute(
        path: '/patient/consultation-history',
        pageBuilder: (_, state) =>
            _quiet(state, const ConsultationHistoryScreen()),
      ),

      // --- Doctor ---
      GoRoute(
        path: '/doctor/onboarding',
        builder: (_, _) => _top(_pro(const DoctorOnboardingScreen())),
      ),
      GoRoute(
        path: '/doctor/pending',
        builder: (_, _) => _top(
          _pro(
            const PendingVerificationView(
              title: 'Awaiting verification',
              description:
                  'Thanks for registering! Before you can see patients, our '
                  'team checks your licence on the KMPDC register.',
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _pro(
          Consumer(
            builder: (context, ref, _) => RoleShell(
              navigationShell: navigationShell,
              tabs: [
                const ShellTab(LucideIcons.house, 'Home'),
                ShellTab(
                  LucideIcons.messagesSquare,
                  'Chats',
                  badge: ref.watch(unreadChatsProvider),
                ),
                const ShellTab(LucideIcons.calendarDays, 'Schedule'),
                const ShellTab(LucideIcons.pill, 'Medicines'),
                const ShellTab(LucideIcons.circleUserRound, 'Profile'),
              ],
            ),
          ),
        ),
        branches: [
          _branch('/doctor', const DoctorDashboardScreen()),
          _branch('/doctor/chats', const ChatsScreen(doctor: true)),
          _branch('/doctor/schedule', const DoctorScheduleScreen()),
          _branch('/doctor/medicines', const DoctorMedicinesScreen()),
          _branch('/doctor/profile', const DoctorProfileEditScreen()),
        ],
      ),
      GoRoute(
        path: '/doctor/history',
        pageBuilder: (_, state) =>
            _quiet(state, _pro(const DoctorHistoryScreen())),
      ),
      GoRoute(
        path: '/doctor/chat/:id',
        builder: (context, state) => _pro(
          ChatScreen(consultationId: state.pathParameters['id']!, doctor: true),
        ),
      ),
      GoRoute(
        path: '/doctor/chat/:id/prescribe',
        builder: (context, state) => _pro(
          ChatPrescribeScreen(consultationId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/doctor/call/:id',
        builder: (context, state) =>
            _pro(DoctorCallScreen(consultationId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/doctor/notifications',
        pageBuilder: (_, state) =>
            _quiet(state, _pro(const NotificationsScreen())),
      ),

      // --- Chemist ---
      GoRoute(
        path: '/chemist/onboarding',
        builder: (_, _) => _top(_pro(const ChemistOnboardingScreen())),
      ),
      GoRoute(
        path: '/chemist/pending',
        builder: (_, _) => _top(
          _pro(
            const PendingVerificationView(
              title: 'Awaiting verification',
              description:
                  'Thanks for registering! Before patients can order from you, '
                  'our team checks your registration with the Pharmacy and '
                  'Poisons Board.',
              what: 'registration',
            ),
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _pro(
          Consumer(
            builder: (context, ref, _) => RoleShell(
              navigationShell: navigationShell,
              tabs: [
                const ShellTab(LucideIcons.layoutDashboard, 'Home'),
                ShellTab(
                  LucideIcons.receipt,
                  'Orders',
                  badge: ref.watch(chemistNewOrderCountProvider),
                ),
                const ShellTab(LucideIcons.boxes, 'Stock'),
                const ShellTab(LucideIcons.circleUserRound, 'Account'),
              ],
            ),
          ),
        ),
        branches: [
          _branch('/chemist', const ChemistDashboardScreen()),
          _branch('/chemist/orders', const ChemistOrdersScreen()),
          _branch('/chemist/stock', const ChemistInventoryScreen()),
          _branch('/chemist/account', const ChemistAccountScreen()),
        ],
      ),

      // --- Admin ---
      ShellRoute(
        builder: (context, state, child) =>
            _pro(AdminShell(location: state.uri.path, child: child)),
        routes: [
          _admin('/admin', (_) => const AdminOverviewScreen()),
          _admin('/admin/activity', (_) => const AdminActivityScreen()),
          _admin('/admin/database', (_) => const AdminDatabaseScreen()),
          _admin(
            '/admin/database/:table',
            (s) => AdminTableBrowserScreen(table: s.pathParameters['table']!),
          ),
          _admin('/admin/users', (_) => const AdminUsersScreen()),
          _admin(
            '/admin/users/:id',
            (s) => AdminUserDetailScreen(userId: s.pathParameters['id']!),
          ),
          _admin('/admin/verification', (_) => const AdminVerificationScreen()),
          _admin(
            '/admin/consultations',
            (_) => const AdminConsultationsScreen(),
          ),
          _admin('/admin/orders', (_) => const AdminOrdersScreen()),
          _admin('/admin/payments', (_) => const AdminPaymentsScreen()),
          _admin('/admin/support', (_) => const AdminSupportScreen()),
          _admin(
            '/admin/support/:id',
            (s) =>
                TicketScreen(ticketId: s.pathParameters['id']!, asStaff: true),
          ),
          _admin('/admin/broadcast', (_) => const AdminBroadcastScreen()),
          _admin('/admin/notifications', (_) => const NotificationsScreen()),
        ],
      ),
      GoRoute(
        path: '/suspended',
        builder: (_, _) => _top(const SuspendedScreen()),
      ),

      // --- Shared by every role (support, map picker) ---
      GoRoute(
        path: '/account/support',
        pageBuilder: (_, state) => _quiet(state, const SupportScreen()),
      ),
      GoRoute(
        path: '/account/support/new',
        builder: (context, state) => NewTicketScreen(
          kind: SupportKind.fromDb(state.uri.queryParameters['kind']),
        ),
      ),
      GoRoute(
        path: '/account/support/:id',
        builder: (context, state) =>
            TicketScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/account/notifications',
        builder: (_, _) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/chemist/import',
        builder: (_, _) => _pro(const StockImportScreen()),
      ),
      GoRoute(
        path: '/chemist/connect',
        builder: (_, _) => _pro(const ConnectSystemScreen()),
      ),
      GoRoute(
        path: '/chemist/notifications',
        pageBuilder: (_, state) =>
            _quiet(state, _pro(const NotificationsScreen())),
      ),
      GoRoute(
        path: '/account/location',
        builder: (context, state) =>
            LocationPickerScreen(initial: state.extra as Place?),
      ),
    ],
  );
});

/// Galleries and lists show their own skeleton while loading, so they open
/// with a quick fade instead of the heartbeat used everywhere else.
Page<void> _quiet(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 240),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (context, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

/// One admin console page (no transition: the sidebar stays put).
GoRoute _admin(String path, Widget Function(GoRouterState) page) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: page(state)),
);

/// One bottom-nav tab of a doctor/chemist shell.
StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);

Future<String?> _redirect(Ref ref, GoRouterState state) async {
  final loggingIn =
      state.matchedLocation == '/auth' ||
      state.matchedLocation.startsWith('/auth/login');

  final userId = ref.read(currentUserIdProvider);
  if (userId == null) {
    return loggingIn ? null : '/auth';
  }
  if (loggingIn || state.matchedLocation == '/') {
    // Fall through below to route by role once we know it.
  }

  // Support and the map picker work the same for every signed-in role.
  if (state.matchedLocation.startsWith('/account/')) return null;

  final appUser = await ref.read(currentAppUserProvider.future);
  if (appUser == null) {
    // Row not created yet (trigger race right after sign-up) -- stay put,
    // the next auth-state/profile refresh will re-run this redirect.
    return null;
  }

  if (appUser.status == UserStatus.suspended) {
    return state.matchedLocation == '/suspended' ? null : '/suspended';
  }
  if (state.matchedLocation == '/suspended') return '/';

  // New here: a few welcome questions before anything else.
  if (appUser.needsWelcome) {
    return state.matchedLocation == '/welcome' ? null : '/welcome';
  }

  switch (appUser.role) {
    case UserRole.patient:
      if (state.matchedLocation.startsWith('/patient')) return null;
      return '/patient';

    case UserRole.doctor:
      final profile = await ref.read(currentDoctorProfileProvider.future);
      final onOnboarding = state.matchedLocation == '/doctor/onboarding';
      final onPending = state.matchedLocation == '/doctor/pending';
      final hasSubmitted = (profile?.licenseNumber ?? '').isNotEmpty;

      if (profile != null && !hasSubmitted) {
        return onOnboarding ? null : '/doctor/onboarding';
      }
      if (profile != null && !profile.licenseVerified) {
        return onPending ? null : '/doctor/pending';
      }
      if (state.matchedLocation.startsWith('/doctor') &&
          !onOnboarding &&
          !onPending) {
        return null;
      }
      return '/doctor';

    case UserRole.chemist:
      final profile = await ref.read(currentChemistProfileProvider.future);
      final onOnboarding = state.matchedLocation == '/chemist/onboarding';
      final onPending = state.matchedLocation == '/chemist/pending';
      final hasSubmitted = (profile?.registrationNumber ?? '').isNotEmpty;

      if (profile != null && !hasSubmitted) {
        return onOnboarding ? null : '/chemist/onboarding';
      }
      if (profile != null && !profile.verified) {
        return onPending ? null : '/chemist/pending';
      }
      if (state.matchedLocation.startsWith('/chemist') &&
          !onOnboarding &&
          !onPending) {
        return null;
      }
      return '/chemist';

    case UserRole.admin:
      if (state.matchedLocation.startsWith('/admin')) return null;
      return '/admin';
  }
}
