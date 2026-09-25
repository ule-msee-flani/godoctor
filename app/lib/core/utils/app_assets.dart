import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Knows which files were actually bundled into the app, so screens can use a
/// real image when one has been supplied and a designed fallback when not --
/// without triggering "asset not found" errors, and without caring whether
/// the file was saved as .png, .jpg or .webp.
///
/// Call [load] once at startup (see main.dart). Until it has run (e.g. in
/// widget tests) every lookup returns null, i.e. "use the fallback".
class AppAssets {
  AppAssets._();

  static const imageExtensions = ['png', 'jpg', 'jpeg', 'webp'];
  static const videoExtensions = ['mp4', 'webm', 'mov'];

  /// lower-cased path -> real bundled path (keeps ".JPG" working).
  static Map<String, String> _bundled = const {};

  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundled = {for (final p in manifest.listAssets()) p.toLowerCase(): p};
    } catch (_) {
      _bundled = const {};
    }
  }

  /// The bundled file for [base] (a path with or without extension), trying
  /// each of [extensions] in order. Null if none was supplied.
  static String? find(
    String base, {
    List<String> extensions = imageExtensions,
  }) {
    final stem = base.replaceFirst(RegExp(r'\.[A-Za-z0-9]{2,4}$'), '');
    for (final ext in extensions) {
      final hit = _bundled['$stem.$ext'.toLowerCase()];
      if (hit != null) return hit;
    }
    return null;
  }

  /// First hit among several candidate bases.
  static String? findFirst(Iterable<String> bases) {
    for (final b in bases) {
      final hit = find(b);
      if (hit != null) return hit;
    }
    return null;
  }

  static String? findVideo(String base) =>
      find(base, extensions: videoExtensions);

  @visibleForTesting
  static void debugSetBundled(Iterable<String> paths) {
    _bundled = {for (final p in paths) p.toLowerCase(): p};
  }
}
