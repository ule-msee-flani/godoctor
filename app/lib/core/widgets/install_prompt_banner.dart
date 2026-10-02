import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../../services/pwa_install_service.dart';
import 'home_screen_guide.dart';

const _dismissedKey = 'install_prompt_dismissed';

/// Shown after the patient's first successful action (per spec), not on
/// landing, in a browser only: on an iPhone or iPad it opens the Add to
/// Home Screen steps; on an Android phone, where to get the app.
class InstallPromptBanner extends StatefulWidget {
  const InstallPromptBanner({super.key});

  @override
  State<InstallPromptBanner> createState() => _InstallPromptBannerState();
}

class _InstallPromptBannerState extends State<InstallPromptBanner> {
  bool _dismissed = true; // default hidden until we've checked prefs

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _dismissed = prefs.getBool(_dismissedKey) ?? false);
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final service = PwaInstallService.instance;
    if (_dismissed || !service.shouldOfferInstall) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.accentTealSoft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: service.isIOS || service.isAndroid
              ? HomeScreenGuide.open
              : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: const Center(
                    child: Icon(
                      LucideIcons.download,
                      color: AppColors.ink,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.isAndroid
                            ? 'Get GoDoctor for Android'
                            : service.isIOS
                            ? 'Add GoDoctor to your Home Screen'
                            : 'Install GoDoctor',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        service.isAndroid
                            ? 'The app for your phone. Tap to get it.'
                            : service.isIOS
                            ? 'It opens full screen, like any other app. Tap '
                                  'to see how.'
                            : 'Look for the install icon in your browser\'s '
                                  'address bar, or use its menu.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 16),
                  onPressed: _dismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
