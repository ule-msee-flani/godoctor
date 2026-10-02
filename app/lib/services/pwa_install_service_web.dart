import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'home_screen_browser.dart';

export 'home_screen_browser.dart';

/// What the browser tells us about this visit: is GoDoctor already opened
/// from the Home Screen, and on which kind of phone and browser.
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  String get _ua {
    try {
      return web.window.navigator.userAgent;
    } catch (_) {
      return '';
    }
  }

  /// Opened from the Home Screen (full screen, no browser around it).
  bool get isRunningStandalone {
    if (!kIsWeb) return false;
    try {
      if (web.window.matchMedia('(display-mode: standalone)').matches) {
        return true;
      }
      // iPhone and iPad say so on navigator.standalone.
      final standalone = (web.window.navigator as JSObject).getProperty(
        'standalone'.toJS,
      );
      return standalone.dartify() == true;
    } catch (_) {
      return false;
    }
  }

  bool get isIOS {
    if (!kIsWeb) return false;
    try {
      return isAppleMobile(
        _ua,
        maxTouchPoints: web.window.navigator.maxTouchPoints,
      );
    } catch (_) {
      return false;
    }
  }

  bool get isAndroid => kIsWeb && isAndroidDevice(_ua);

  HomeScreenBrowser get browser => homeScreenBrowserFor(_ua);

  /// iPads keep Safari's buttons at the top of the screen.
  bool get isIPad => isIOS && !RegExp(r'iPhone|iPod').hasMatch(_ua);

  /// This page's address (to copy into Safari).
  String get currentUrl {
    try {
      return web.window.location.href;
    } catch (_) {
      return '';
    }
  }

  /// Opens [url] in this tab (the download page, for Android phones).
  void open(String url) {
    try {
      web.window.location.href = url;
    } catch (_) {}
  }

  /// Whether the install nudge is worth showing at all right now.
  bool get shouldOfferInstall => kIsWeb && !isRunningStandalone;
}
