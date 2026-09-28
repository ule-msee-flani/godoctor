import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';
import '../models/chemist_profile.dart';
import '../models/doctor_profile.dart';
import '../models/patient_profile.dart';
import 'repository_providers.dart';
import '../../services/live_updates.dart';

/// Emits every auth state change (sign in/out/token refresh) so the router
/// can redirect reactively.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// The current Supabase auth user id, or null if signed out. Derived from
/// [authStateChangesProvider] so it updates on sign-in/out without a manual
/// refresh; falls back to reading the session directly on first build.
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateChangesProvider).valueOrNull;
  return authState?.session?.user.id ??
      ref.watch(authRepositoryProvider).currentAuthUser?.id;
});

/// The `public.users` row for the signed-in user (role, status). Re-fetches
/// whenever the auth id changes.
final currentAppUserProvider = FutureProvider<AppUser?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchUser(userId);
});

final currentPatientProfileProvider = FutureProvider<PatientProfile?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchPatientProfile(userId);
});

final currentDoctorProfileProvider = FutureProvider<DoctorProfile?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(liveTick(LiveTable.doctors));
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchDoctorProfile(userId);
});

final currentChemistProfileProvider = FutureProvider<ChemistProfile?>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchChemistProfile(userId);
});
