import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/config/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await SupabaseService.initialize();
  runApp(const ProviderScope(child: GoDoctorApp()));
}

class GoDoctorApp extends ConsumerWidget {
  const GoDoctorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) {
      return const _ConfigMissingApp();
    }

    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'GoDoctor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.patientTheme,
      routerConfig: router,
    );
  }
}

/// Friendly guard for the "hasn't filled in .env yet" state, instead of a
/// cryptic Supabase connection error on first run.
class _ConfigMissingApp extends StatelessWidget {
  const _ConfigMissingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_outlined, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Supabase isn\'t configured yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Copy app/.env.example to app/.env and fill in your '
                  'Supabase project URL and anon key, then restart.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
