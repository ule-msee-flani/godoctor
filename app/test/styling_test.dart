import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/utils/app_assets.dart';
import 'package:godoctor_app/core/widgets/splash_gate.dart';
import 'package:godoctor_app/data/models/doctor_profile.dart';
import 'package:godoctor_app/features/patient/specialties/content/ent_content.dart';
import 'package:godoctor_app/features/patient/specialties/specialty_page.dart';
import 'package:godoctor_app/features/patient/specialties/specialty_registry.dart';
import 'package:godoctor_app/features/patient/widgets/specialty_tiles.dart';
import 'package:video_player/video_player.dart';

void main() {
  setUp(() => AppAssets.debugSetBundled(const []));

  group('specialty pages', () {
    test('every tile has a page and every page has a tile', () {
      expect(kSpecialtyContents.length, kSpecialtyMeta.length);
      for (final meta in kSpecialtyMeta) {
        final content = specialtyContentForSlug(meta.slug);
        expect(content, isNotNull, reason: 'no page for ${meta.slug}');
        expect(content!.name, meta.name, reason: meta.slug);
        expect(kSpecialties, contains(content.name));
      }
    });

    test('no page is left half-written', () {
      for (final c in kSpecialtyContents) {
        expect(c.title, isNotEmpty, reason: c.slug);
        expect(c.tagline, isNotEmpty, reason: c.slug);
        expect(c.about, isNotEmpty, reason: c.slug);
        expect(c.commonReasons.length, greaterThanOrEqualTo(3), reason: c.slug);
        expect(c.onlineHelp, isNotEmpty, reason: c.slug);
        // Safety: every page must tell people when it is an emergency.
        expect(c.urgentSigns, isNotEmpty, reason: c.slug);
        expect(c.findDoctorsLabel, isNotEmpty, reason: c.slug);
      }
    });

    test('slugs are unique', () {
      final slugs = kSpecialtyContents.map((c) => c.slug).toList();
      expect(slugs.toSet().length, slugs.length);
    });

    testWidgets(
      'a specialty page shows its content, emergency box and button',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const MaterialApp(home: SpecialtyPage(content: entContent)),
        );

        expect(find.text('Ear, Nose & Throat (ENT)'), findsOneWidget);
        expect(find.text('Find ENT doctors'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Get urgent help instead if you have'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Call 999 (Emergency)'), findsOneWidget);
      },
    );
  });

  group('splash', () {
    testWidgets('does nothing when no video has been supplied', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashGate(child: Text('the app'))),
      );
      await tester.pump();

      expect(find.text('the app'), findsOneWidget);
      expect(find.byType(VideoPlayer), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
    });
  });

  group('specialty tiles', () {
    testWidgets('fall back to an icon until a picture is supplied', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SpecialtyMeta? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SpecialtyCarousel(onSelected: (m) => picked = m),
          ),
        ),
      );
      // Two big cards per page.
      expect(find.text('General Practice'), findsOneWidget);
      expect(find.text("Children's Health"), findsOneWidget);
      expect(find.text("Women's Health"), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(SpecialtyCard), findsNWidgets(2));

      // Swipe for the next two.
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      expect(find.text("Women's Health"), findsOneWidget);
      expect(find.text('Internal Medicine'), findsOneWidget);
      await tester.tap(find.widgetWithText(SpecialtyCard, 'Internal Medicine'));
      await tester.pumpAndSettle();
      expect(picked?.slug, 'internal');
    });
  });
}
