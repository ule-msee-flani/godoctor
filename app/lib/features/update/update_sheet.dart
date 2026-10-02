import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:ota_update/ota_update.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/settings_section.dart';
import '../../services/app_update.dart';
import '../auth/widgets/auth_hero.dart' show AppIconMark;

/// "A new version of GoDoctor is ready": what's new, then download it
/// inside the app (with progress) and hand it to Android's installer.
Future<void> showUpdateSheet(
  BuildContext context,
  AppRelease release, {
  required String installedVersion,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _UpdateSheet(release: release, installedVersion: installedVersion),
  );
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({required this.release, required this.installedVersion});

  final AppRelease release;
  final String installedVersion;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  StreamSubscription<OtaEvent>? _sub;
  double? _progress;
  bool _installing = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      _sub = OtaUpdate()
          .execute(
            widget.release.apkUrl,
            destinationFilename: 'GoDoctor-${widget.release.version}.apk',
          )
          .listen(
            (e) {
              if (!mounted) return;
              switch (e.status) {
                case OtaStatus.DOWNLOADING:
                  setState(
                    () =>
                        _progress = (double.tryParse(e.value ?? '') ?? 0) / 100,
                  );
                case OtaStatus.INSTALLING:
                case OtaStatus.INSTALLATION_DONE:
                  setState(() {
                    _progress = 1;
                    _installing = true;
                  });
                case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                  setState(() {
                    _progress = null;
                    _error =
                        'Allow GoDoctor to install updates (Android asks the first '
                        'time), then tap Update again.';
                  });
                case OtaStatus.ALREADY_RUNNING_ERROR:
                  break;
                default:
                  setState(() {
                    _progress = null;
                    _error =
                        'The download didn\'t finish. Check your connection and try again.';
                  });
              }
            },
            onError: (_) {
              if (mounted) {
                setState(() {
                  _progress = null;
                  _error =
                      'The download didn\'t finish. Check your connection and try again.';
                });
              }
            },
          );
    } catch (_) {
      setState(() {
        _progress = null;
        _error = 'Updates can\'t be installed on this device.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final r = widget.release;
    final downloading = _progress != null && !_installing;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppIconMark(size: 56)),
            const SizedBox(height: 14),
            Text(
              'A new version of GoDoctor is ready',
              textAlign: TextAlign.center,
              style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              [
                'Version ${r.version}',
                'you have ${widget.installedVersion}',
                if (r.sizeLabel.isNotEmpty) r.sizeLabel,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: theme.bodySmall,
            ),
            if (r.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('What\'s new', style: theme.labelLarge),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final n in r.notes.take(8))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(
                                  LucideIcons.sparkles,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(n, style: theme.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (downloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 8,
                  backgroundColor: AppColors.primarySoft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Downloading… ${((_progress ?? 0) * 100).round()}%',
                textAlign: TextAlign.center,
                style: theme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Keep GoDoctor open. Android will then ask you to install.',
                textAlign: TextAlign.center,
                style: theme.bodySmall,
              ),
            ] else if (_installing)
              Text(
                'Tap "Update" on the Android screen to finish.',
                textAlign: TextAlign.center,
                style: theme.titleSmall,
              )
            else ...[
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                ),
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(LucideIcons.download, size: 18),
                label: const Text('Update now'),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  UpdateSnooze.snooze(r);
                  Navigator.pop(context);
                },
                child: const Text('Later'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Settings row: "App version 1.1.0 · Check for updates".
class AppVersionTile extends ConsumerStatefulWidget {
  const AppVersionTile({super.key});

  @override
  ConsumerState<AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends ConsumerState<AppVersionTile> {
  bool _checking = false;

  Future<void> _check() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!inAppUpdatesSupported) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'GoDoctor updates itself. You\'re on the latest version.',
          ),
        ),
      );
      return;
    }
    setState(() => _checking = true);
    ref.invalidate(latestReleaseProvider);
    final update = await ref.read(availableUpdateProvider.future);
    final installed = await ref.read(installedVersionProvider.future);
    if (!mounted) return;
    setState(() => _checking = false);
    if (update == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('You have the latest version of GoDoctor.'),
        ),
      );
    } else {
      await showUpdateSheet(
        context,
        update,
        installedVersion: installed.version,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedVersionProvider).valueOrNull;
    final update = ref.watch(availableUpdateProvider).valueOrNull;
    return SettingsTile(
      icon: LucideIcons.refreshCw,
      title: update != null ? 'Update available' : 'App version',
      subtitle: _checking
          ? 'Checking…'
          : update != null
          ? 'Version ${update.version} is ready to install'
          : !inAppUpdatesSupported
          ? (installed == null
                ? 'Updates automatically'
                : 'Version ${installed.version} · Updates automatically')
          : installed == null
          ? 'Check for updates'
          : 'Version ${installed.version} · Check for updates',
      badge: update != null ? 1 : 0,
      onTap: _checking ? () {} : _check,
    );
  }
}
