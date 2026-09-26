import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/models/drug.dart';
import '../../data/models/enums.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../features/admin/screens/admin_verification_screen.dart';
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
import '../../features/patient/screens/activity_screen.dart';
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
import '../../features/prescription/prescription_order_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/pending_verification_view.dart';
import '../widgets/role_shell.dart';
import 'go_router_refresh_stream.dart';

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
  final authRepo = ref.watch(authRepositoryProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authRepo.onAuthStateChange),
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
                path: '/patient/activity',
                builder: (_, _) => const ActivityScreen(),
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
      GoRoute(
        path: '/patient/intake',
        builder: (context, state) => IntakeFormScreen(
          initialSpecialty: state.uri.queryParameters['specialty'],
          initialSymptoms: state.uri.queryParameters['symptoms'],
        ),
      ),
      GoRoute(
        path: '/patient/consult/doctors',
        builder: (_, _) => const AvailableDoctorsScreen(),
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
        path: '/patient/notifications',
        builder: (_, _) => const NotificationsScreen(),
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
        builder: (_, _) => const PrescriptionsScreen(),
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
        builder: (_, _) => const MedicineSearchScreen(),
      ),
      GoRoute(
        path: '/patient/chemist-select/:drugId',
        builder: (context, state) =>
            ChemistSelectScreen(drugId: state.pathParameters['drugId']!),
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
        builder: (_, _) => const OrderHistoryScreen(),
      ),
      GoRoute(
        path: '/patient/consultation-history',
        builder: (_, _) => const ConsultationHistoryScreen(),
      ),

      // --- Doctor ---
      GoRoute(
        path: '/doctor/onboarding',
        builder: (_, _) => _pro(const DoctorOnboardingScreen()),
      ),
      GoRoute(
        path: '/doctor/pending',
        builder: (_, _) => _pro(
          const PendingVerificationView(
            title: 'Your license is under review',
            description:
                'An admin manually checks the public KMPDC register before you can start '
                'accepting consultations. This usually takes 1-2 business days.',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _pro(
          RoleShell(
            navigationShell: navigationShell,
            tabs: const [
              ShellTab(LucideIcons.house, 'Home'),
              ShellTab(LucideIcons.calendarDays, 'Schedule'),
              ShellTab(LucideIcons.pill, 'Medicines'),
              ShellTab(LucideIcons.history, 'History'),
              ShellTab(LucideIcons.circleUserRound, 'Profile'),
            ],
          ),
        ),
        branches: [
          _branch('/doctor', const DoctorDashboardScreen()),
          _branch('/doctor/schedule', const DoctorScheduleScreen()),
          _branch('/doctor/medicines', const DoctorMedicinesScreen()),
          _branch('/doctor/history', const DoctorHistoryScreen()),
          _branch('/doctor/profile', const DoctorProfileEditScreen()),
        ],
      ),
      GoRoute(
        path: '/doctor/call/:id',
        builder: (context, state) =>
            _pro(DoctorCallScreen(consultationId: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/doctor/notifications',
        builder: (_, _) =>
            _pro(const NotificationsScreen(appointmentRoute: null)),
      ),

      // --- Chemist ---
      GoRoute(
        path: '/chemist/onboarding',
        builder: (_, _) => _pro(const ChemistOnboardingScreen()),
      ),
      GoRoute(
        path: '/chemist/pending',
        builder: (_, _) => _pro(
          const PendingVerificationView(
            title: 'Your registration is under review',
            description:
                'An admin verifies your pharmacy registration before your inventory is '
                'listed publicly. This usually takes 1-2 business days.',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => _pro(
          Consumer(
            builder: (context, ref, _) => RoleShell(
              navigationShell: navigationShell,
              tabs: [
                ShellTab(
                  LucideIcons.receipt,
                  'Orders',
                  badge: ref.watch(chemistNewOrderCountProvider),
                ),
                const ShellTab(LucideIcons.boxes, 'Stock'),
              ],
            ),
          ),
        ),
        branches: [
          _branch('/chemist', const ChemistOrdersScreen()),
          _branch('/chemist/stock', const ChemistInventoryScreen()),
        ],
      ),

      // --- Admin ---
      GoRoute(
        path: '/admin',
        builder: (_, _) => _pro(const AdminVerificationScreen()),
      ),
    ],
  );
});

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

  final appUser = await ref.read(currentAppUserProvider.future);
  if (appUser == null) {
    // Row not created yet (trigger race right after sign-up) -- stay put,
    // the next auth-state/profile refresh will re-run this redirect.
    return null;
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
