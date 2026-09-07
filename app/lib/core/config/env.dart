import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Central place to read environment/config values.
///
/// Values come from `.env` (git-ignored, loaded via flutter_dotenv at startup
/// in `main.dart`). Copy `.env.example` to `.env` and fill in your Supabase
/// project's URL + anon key before running the app for real.
class Env {
  Env._();

  static String get supabaseUrl => dotenv.get('SUPABASE_URL', fallback: '');
  static String get supabaseAnonKey =>
      dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('placeholder') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseAnonKey.contains('placeholder');
}
