import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Published next to every APK by the release workflow
/// (.github/workflows/release-apk.yml). GitHub redirects "latest" to the
/// newest release, so this never needs the (rate-limited) GitHub API.
const kLatestReleaseUrl =
    'https://github.com/ule-msee-flani/godoctor/releases/latest/download/version.json';

/// In-app updates are for the Android app installed from the APK; the web
/// app updates itself.
bool get inAppUpdatesSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// A published version of the app.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    required this.apkUrl,
    this.sizeBytes,
    this.notes = const [],
  });

  final String version;

  /// Android versionCode (the release workflow's run number).
  final int build;
  final String apkUrl;
  final int? sizeBytes;
  final List<String> notes;

  String get sizeLabel => sizeBytes == null
      ? ''
      : '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(0)} MB';

  static AppRelease? tryParse(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final url = m['apk'] as String?;
      final build = (m['build'] as num?)?.toInt();
      if (url == null || build == null || !url.startsWith('https://')) {
        return null;
      }
      return AppRelease(
        version: (m['version'] as String?) ?? '',
        build: build,
        apkUrl: url,
        sizeBytes: (m['size'] as num?)?.toInt(),
        notes: [
          for (final n in (m['notes'] as List?) ?? const [])
            if ('$n'.trim().isNotEmpty) '$n'.trim(),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

/// This install's version and build number.
final installedVersionProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// The newest published release, or null (offline, or not published yet).
final latestReleaseProvider = FutureProvider.autoDispose<AppRelease?>((
  ref,
) async {
  if (!inAppUpdatesSupported) return null;
  try {
    final res = await http
        .get(Uri.parse(kLatestReleaseUrl))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return null;
    return AppRelease.tryParse(res.body);
  } catch (_) {
    return null;
  }
});

/// A release newer than this install, if there is one.
final availableUpdateProvider = FutureProvider.autoDispose<AppRelease?>((
  ref,
) async {
  if (!inAppUpdatesSupported) return null;
  final installed = await ref.watch(installedVersionProvider.future);
  final latest = await ref.watch(latestReleaseProvider.future);
  return isNewerRelease(latest, int.tryParse(installed.buildNumber) ?? 0)
      ? latest
      : null;
});

bool isNewerRelease(AppRelease? release, int installedBuild) =>
    release != null && release.build > installedBuild;

/// "Later" hides the prompt for that version for a day.
class UpdateSnooze {
  static const _key = 'update_snoozed';

  static Future<bool> isSnoozed(AppRelease r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key);
      if (v == null) return false;
      final parts = v.split('|');
      final until = DateTime.tryParse(parts.last);
      return parts.first == '${r.build}' &&
          until != null &&
          DateTime.now().isBefore(until);
    } catch (_) {
      return false;
    }
  }

  static Future<void> snooze(AppRelease r) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(const Duration(days: 1));
      await prefs.setString(_key, '${r.build}|${until.toIso8601String()}');
    } catch (_) {}
  }
}
