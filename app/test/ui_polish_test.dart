// The visual pass: calm screen changes (without ever rebuilding the page
// underneath), the heartbeat only for waits you'd notice, black icons, and
// the pictures the home and specialty tiles rely on.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/heartbeat_loader.dart';
import 'package:godoctor_app/core/widgets/loading_view.dart';
import 'package:godoctor_app/features/patient/widgets/specialty_tiles.dart';

/// Counts how often its State is created (a rebuilt-from-scratch page would
/// lose text fields, scroll position and loaded data).
class _Probe extends StatefulWidget {
  const _Probe();

  static int created = 0;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    _Probe.created++;
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('next screen')));
}

void main() {
  testWidgets('screen change: a calm slide, no heartbeat, page built once', (
    tester,
  ) async {
    _Probe.created = 0;
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: nav,
        theme: AppTheme.patientTheme,
        home: const Scaffold(body: Text('first')),
      ),
    );
    nav.currentState!.push(MaterialPageRoute(builder: (_) => const _Probe()));

    await tester.pump(); // route added
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(HeartbeatLoader), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('next screen'), findsOneWidget);
    expect(_Probe.created, 1, reason: 'the page must not be rebuilt');

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
  });

  testWidgets('loading: the heartbeat only shows when the wait is noticeable', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.patientTheme,
        home: const Scaffold(body: LoadingView(message: 'Loading your data')),
      ),
    );
    // A quick load never flashes the heartbeat.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HeartbeatLoader), findsNothing);
    // A longer one does.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(HeartbeatLoader), findsOneWidget);
    expect(find.text('Loading your data'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('theme: Inter font, black icons, no tab indicator pill', () {
    for (final theme in [AppTheme.patientTheme, AppTheme.professionalTheme]) {
      expect(theme.textTheme.titleMedium?.fontFamily, startsWith('Inter'));
      expect(theme.iconTheme.color, const Color(0xFF0B1730));
      expect(theme.navigationBarTheme.indicatorColor, Colors.transparent);
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<CalmPageTransitionsBuilder>(),
      );
    }
  });

  group('pictures are in place', () {
    bool exists(String base) => [
      'png',
      'jpg',
      'jpeg',
      'webp',
    ].any((ext) => File('$base.$ext').existsSync());

    test('home tiles', () {
      expect(exists('assets/images/home/see_doctor'), isTrue);
      expect(exists('assets/images/home/order_medicine'), isTrue);
    });

    test('every specialty has a picture', () {
      for (final meta in kSpecialtyMeta) {
        expect(exists(meta.imageBase), isTrue, reason: meta.slug);
      }
    });

    test('the home folder is bundled', () {
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/images/home/'),
      );
    });
  });
}
