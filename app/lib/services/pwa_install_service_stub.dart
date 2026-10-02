import 'home_screen_browser.dart';

export 'home_screen_browser.dart';

/// Away from the web (the Android app, and `flutter test` on the Dart VM,
/// which can't compile `package:web`): there's no browser, so nothing to
/// install. See `pwa_install_service.dart` for how this is picked.
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  bool get isRunningStandalone => false;
  bool get isIOS => false;
  bool get isAndroid => false;
  bool get isIPad => false;
  HomeScreenBrowser get browser => HomeScreenBrowser.other;
  String get currentUrl => '';
  void open(String url) {}
  bool get shouldOfferInstall => false;
}
