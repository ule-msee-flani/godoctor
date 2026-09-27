import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../../services/push_service.dart';
import '../models/enums.dart';

/// Wraps Supabase Auth. Email + password for now (phone OTP may come back
/// later, once SMS is set up).
class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Registration: role is stashed in user metadata; a DB trigger
  /// (`handle_new_auth_user`) creates the `public.users` + profile row.
  ///
  /// Returns true when the account still has to be confirmed from the email
  /// Supabase sends (no session yet).
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required UserRole role,
    required String name,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': EnumDbCoding.toDb(role), 'name': name},
    );
    return res.session == null;
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    // Stop this device receiving the account's notifications first (needs
    // the session, so it must happen before signing out).
    await PushService.current?.unregisterDevice();
    await _client.auth.signOut();
  }

  Future<void> changePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));
}
