import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_abi.dart';

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

  /// [abi] is this phone's CPU type; releases carry one APK per type
  /// ("apks") and the phone downloads only its own. "apk" is the fallback
  /// (and what older app versions read).
  static AppRelease? tryParse(String body, {String? abi}) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      var url = m['apk'] as String?;
      var size = (m['size'] as num?)?.toInt();
      final mine = (m['apks'] as Map?)?[abi ?? currentAndroidAbi()];
      if (mine is Map && mine['url'] is String) {
        url = mine['url'] as String;
        size = (mine['size'] as num?)?.toInt();
      }
      final build = (m['build'] as num?)?.toInt();
      if (url == null || build == null || !url.startsWith('https://')) {
        return null;
      }
      return AppRelease(
        version: (m['version'] as String?) ?? '',
        build: build,
        apkUrl: url,
        sizeBytes: size,
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
  return isNewerRelease(
        latest,
        releaseNumber(int.tryParse(installed.buildNumber) ?? 0),
      )
      ? latest
      : null;
});

bool isNewerRelease(AppRelease? release, int installedBuild) =>
    release != null && release.build > installedBuild;

/// The release number inside an Android versionCode. APKs built per CPU
/// type carry it with the type in front (arm64: 2000 + n, 32-bit: 1000 + n),
/// so compare only the last three digits.
int releaseNumber(int versionCode) => versionCode % 1000;

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
