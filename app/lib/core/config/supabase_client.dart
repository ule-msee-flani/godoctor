import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

/// Thin wrapper so the rest of the app never imports `supabase_flutter`
/// directly for client access -- makes it easy to swap/mock in tests.
class SupabaseService {
  SupabaseService._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // `anonKey` is deprecated in favor of `publishableKey` (Supabase's new
      // API key format), but most existing projects -- including a
      // freshly-created one today -- still issue the legacy anon JWT. Switch
      // this to `publishableKey` once the project's dashboard shows a
      // "publishable key" instead of/alongside "anon key".
      // ignore: deprecated_member_use
      anonKey: Env.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}
