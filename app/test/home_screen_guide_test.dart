// The web app on phones: telling browsers apart, and the Add to Home
// Screen steps for each one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/core/widgets/home_screen_guide.dart';
import 'package:godoctor_app/services/home_screen_browser.dart';

const _safari26 =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 '
    'Safari/604.1';
const _safari17 =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 '
    'Safari/604.1';
const _chrome =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/140.0.7339.122 '
    'Mobile/15E148 Safari/604.1';
const _edge =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 EdgiOS/140.0.3485.70 '
    'Mobile/15E148 Safari/605.1.15';
const _firefox =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/143.0 Mobile/15E148 '
    'Safari/605.1.15';
const _instagram =
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) '
    'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram '
    '380.0.0.0.0';
const _iPadDesktop =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
    '(KHTML, like Gecko) Version/26.0 Safari/605.1.15';
const _androidChrome =
    'Mozilla/5.0 (Linux; Android 14; SM-A156E) AppleWebKit/537.36 (KHTML, '
    'like Gecko) Chrome/140.0.0.0 Mobile Safari/537.36';

void main() {
  test('tells iPhone browsers apart', () {
    expect(homeScreenBrowserFor(_safari26), HomeScreenBrowser.safariNew);
    expect(homeScreenBrowserFor(_safari17), HomeScreenBrowser.safari);
    expect(homeScreenBrowserFor(_chrome), HomeScreenBrowser.chrome);
    expect(homeScreenBrowserFor(_edge), HomeScreenBrowser.edge);
    expect(homeScreenBrowserFor(_firefox), HomeScreenBrowser.firefox);
    expect(homeScreenBrowserFor(_instagram), HomeScreenBrowser.inApp);
  });

  test('tells iPhones, iPads and Android phones apart', () {
    expect(isAppleMobile(_safari26), isTrue);
    expect(isAppleMobile(_iPadDesktop, maxTouchPoints: 5), isTrue);
    expect(isAppleMobile(_iPadDesktop), isFalse, reason: 'a Mac');
    expect(isAppleMobile(_androidChrome), isFalse);
    expect(isAndroidDevice(_androidChrome), isTrue);
    expect(isAndroidDevice(_safari26), isFalse);
  });

  test('the steps point at the right buttons', () {
    String steps(HomeScreenBrowser b, {bool iPad = false}) =>
        homeScreenSteps(b, iPad: iPad).map((s) => s.text).join(' | ');
    expect(steps(HomeScreenBrowser.safariNew), contains('Tap ••• at the bottom'));
    expect(steps(HomeScreenBrowser.safariNew), contains('Open as Web App'));
    expect(steps(HomeScreenBrowser.safari), startsWith('Tap the Share button'));
    expect(
      steps(HomeScreenBrowser.safari, iPad: true),
      contains('at the top right'),
    );
    expect(steps(HomeScreenBrowser.chrome), contains('address bar'));
    expect(steps(HomeScreenBrowser.firefox), contains('menu ☰'));
    expect(steps(HomeScreenBrowser.inApp), contains('Open in Safari'));
  });

  for (final browser in HomeScreenBrowser.values) {
    testWidgets('the guide fits a small iPhone (${browser.name})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var done = false, later = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.patientTheme,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: HomeScreenSteps(
                browser: browser,
                link: 'https://example.com/app/',
                onDone: () => done = true,
                onNotNow: () => later = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final inApp = browser == HomeScreenBrowser.inApp;
      expect(
        find.text(
          inApp ? 'Open GoDoctor in Safari' : 'Add GoDoctor to your Home Screen',
        ),
        findsOneWidget,
      );
      if (inApp) expect(find.text('Copy the link'), findsOneWidget);
      await tester.ensureVisible(find.text('Not now'));
      await tester.tap(find.text('Not now'));
      expect(later, isTrue);
      final doneLabel = inApp ? 'Got it' : 'I\'ve added it';
      await tester.ensureVisible(find.text(doneLabel));
      await tester.tap(find.text(doneLabel));
      expect(done, isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('the guide never shows in the Android app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreenGuide(child: Text('APP'))),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('APP'), findsOneWidget);
    expect(find.text('Add GoDoctor to your Home Screen'), findsNothing);
    expect(find.text('Get GoDoctor for Android'), findsNothing);
  });
}
