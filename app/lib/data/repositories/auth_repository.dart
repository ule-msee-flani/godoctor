import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_client.dart';
import '../../services/push_service.dart';
import '../models/enums.dart';

/// Wraps Supabase Auth. Phone/OTP is the primary login method for the
/// Kenyan market; email+password is the fallback (per spec).
class AuthRepository {
  SupabaseClient get _client => SupabaseService.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Registration: role is stashed in user metadata; a DB trigger
  /// (`handle_new_auth_user`) creates the `public.users` + profile row.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required UserRole role,
    required String name,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': EnumDbCoding.toDb(role), 'name': name},
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sends an OTP SMS to [phone] (E.164 format, e.g. +2547XXXXXXXX).
  /// [role]/[name] are only used the first time (new-user sign-up path) --
  /// Supabase's phone OTP covers both sign-up and sign-in with one call.
  Future<void> requestPhoneOtp({
    required String phone,
    UserRole? role,
    String? name,
  }) async {
    await _client.auth.signInWithOtp(
      phone: phone,
      data: role != null
          ? {'role': EnumDbCoding.toDb(role), 'name': name ?? ''}
          : null,
    );
  }

  Future<void> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) async {
    await _client.auth.verifyOTP(phone: phone, token: otp, type: OtpType.sms);
  }

  Future<void> signOut() async {
    // Stop this device receiving the account's notifications first (needs
    // the session, so it must happen before signing out).
    await PushService.current?.unregisterDevice();
    await _client.auth.signOut();
  }

  /// For email accounts (phone accounts sign in with a code instead).
  Future<void> changePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));
}
