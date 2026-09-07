import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/pwa_install_service.dart';

const _dismissedKey = 'install_prompt_dismissed';

/// Shown after the patient's first successful action (per spec), not on
/// landing. Gives iOS users the manual walkthrough (no native install
/// prompt exists there) and a lighter nudge elsewhere.
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

    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.add_to_home_screen),
        title: const Text('Install GoDoctor'),
        subtitle: Text(
          service.isIOS
              ? 'Add it to your home screen for faster access and notifications.'
              : 'Look for the install icon in your browser\'s address bar, or use its menu.',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _dismiss,
        ),
        onTap: service.isIOS
            ? () => showDialog(
                context: context,
                builder: (_) => const _IosInstallDialog(),
              )
            : null,
      ),
    );
  }
}

class _IosInstallDialog extends StatelessWidget {
  const _IosInstallDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Home Screen'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Step(number: 1, text: 'Tap the Share icon in Safari\'s toolbar.'),
          _Step(number: 2, text: 'Scroll down and tap "Add to Home Screen".'),
          _Step(number: 3, text: 'Tap "Add" in the top-right corner.'),
          SizedBox(height: 8),
          Text(
            'Notifications only work once GoDoctor is installed this way.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Got it'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 11, child: Text('$number', style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
