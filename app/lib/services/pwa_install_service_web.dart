import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Detects install-to-home-screen state so the UI can nudge patients at the
/// right moment (per spec: "prompt users to install after their first
/// successful action, not on landing").
///
/// Deliberately does NOT try to capture and replay the `beforeinstallprompt`
/// event to trigger Android/desktop Chrome's native install UI programmatically
/// -- that event only fires under specific engagement heuristics that can't be
/// exercised/verified outside a real deployed HTTPS origin, so replaying it
/// wrong would be silent dead code. Chrome/Edge/desktop already surface their
/// own install affordance (address-bar icon) once the manifest + service
/// worker are valid, which `flutter create --platforms=web` already set up;
/// this service just tells the UI when to *remind* the user to look for it,
/// and gives iOS Safari (which has no such icon) explicit steps instead.
class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  bool get isRunningStandalone {
    if (!kIsWeb) return false;
    try {
      return web.window.matchMedia('(display-mode: standalone)').matches;
    } catch (_) {
      return false;
    }
  }

  bool get isIOS {
    if (!kIsWeb) return false;
    try {
      final ua = web.window.navigator.userAgent;
      return RegExp(r'iPhone|iPad|iPod', caseSensitive: false).hasMatch(ua);
    } catch (_) {
      return false;
    }
  }

  /// Whether the install nudge is worth showing at all right now.
  bool get shouldOfferInstall => kIsWeb && !isRunningStandalone;
}
