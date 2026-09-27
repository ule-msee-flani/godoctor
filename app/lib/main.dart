import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/env.dart';
import 'core/utils/app_assets.dart';
import 'core/config/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/splash_gate.dart';
import 'features/update/update_sheet.dart';
import 'services/app_update.dart';
import 'services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await AppAssets.load();
  await SupabaseService.initialize();
  await initFirebase();
  runApp(const ProviderScope(child: GoDoctorApp()));
}

/// The update prompt is shown at most once per app launch.
bool _offeredUpdate = false;

class GoDoctorApp extends ConsumerWidget {
  const GoDoctorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) {
      return const _ConfigMissingApp();
    }

    final router = ref.watch(appRouterProvider);
    // Push notifications for whoever is signed in.
    ref.watch(pushServiceProvider);
    // A newer APK published? Offer it once per launch, after the intro.
    ref.listen(availableUpdateProvider, (_, next) async {
      final release = next.valueOrNull;
      if (release == null || _offeredUpdate) return;
      _offeredUpdate = true;
      if (await UpdateSnooze.isSnoozed(release)) return;
      await Future<void>.delayed(const Duration(seconds: 5));
      final installed = await ref.read(installedVersionProvider.future);
      final ctx = router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await showUpdateSheet(ctx, release, installedVersion: installed.version);
    });
    return MaterialApp.router(
      title: 'GoDoctor',
      scaffoldMessengerKey: pushMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.patientTheme,
      routerConfig: router,
      // The launch video plays over the app while it starts up.
      builder: (context, child) =>
          SplashGate(child: child ?? const SizedBox.shrink()),
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
