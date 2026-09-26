import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import '../../services/push_service.dart';

final _mutedProvider = FutureProvider.autoDispose<Set<String>>(
  (ref) => ref.watch(notificationRepositoryProvider).mutedCategories(),
);

/// Is push allowed on this device? (null = push not available here)
final _permittedProvider = FutureProvider.autoDispose<bool?>((ref) async {
  final push = PushService.current;
  if (!firebaseReady || push == null) return null;
  return push.permitted;
});

/// Notification settings (every role): device permission, which kinds of
/// alerts to receive, and a test notification.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  Set<String>? _muted;
  bool _sending = false;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _toggle(String category, bool on) async {
    final next = {...?(_muted ?? ref.read(_mutedProvider).valueOrNull)};
    on ? next.remove(category) : next.add(category);
    setState(() => _muted = next);
    try {
      await ref.read(notificationRepositoryProvider).setMutedCategories(next);
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  Future<void> _sendTest() async {
    setState(() => _sending = true);
    try {
      await ref.read(notificationRepositoryProvider).sendTest();
      if (mounted) {
        _toast('Sent. It should arrive in a few seconds.');
      }
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _turnOn() async {
    await PushService.current?.registerDevice();
    ref.invalidate(_permittedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final muted = _muted ?? ref.watch(_mutedProvider).valueOrNull;
    final permitted = ref.watch(_permittedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _DeviceStatus(permitted: permitted, onTurnOn: _turnOn),
          const SizedBox(height: 22),
          Text('What to notify me about', style: theme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Everything also stays in your notification inbox in the app.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 10),
          Card(
            child: muted == null
                ? const SizedBox(height: 160, child: LoadingView())
                : Column(
                    children: [
                      for (var i = 0; i < kPushCategories.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CategoryRow(
                          category: kPushCategories[i],
                          on: !muted.contains(kPushCategories[i].id),
                          locked: kPushCategories[i].id == 'urgent',
                          onChanged: (v) =>
                              _toggle(kPushCategories[i].id, v),
                        ),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: _sending ? null : _sendTest,
            icon: const Icon(LucideIcons.bellRing, size: 18),
            label: Text(_sending ? 'Sending…' : 'Send me a test notification'),
          ),
          const SizedBox(height: 10),
          Text(
            'On some phones (OPPO, Xiaomi, Tecno, Infinix) battery saving can '
            'delay notifications. If alerts arrive late, allow GoDoctor to run '
            'in the background in your phone\'s battery settings.',
            style: theme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({required this.permitted, required this.onTurnOn});

  final AsyncValue<bool?> permitted;
  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final value = permitted.valueOrNull;
    final (icon, title, body) = switch (value) {
      true => (
        LucideIcons.bellRing,
        'Notifications are on',
        'This device will alert you, even when GoDoctor is closed.',
      ),
      false => (
        LucideIcons.bellOff,
        'Notifications are off on this device',
        'Turn them on so you don\'t miss your doctor, your prescriptions or your orders.',
      ),
      null => (
        LucideIcons.bell,
        permitted.isLoading ? 'Checking…' : 'Alerts appear in your inbox',
        'Phone notifications aren\'t available on this device. You\'ll still '
            'see everything in the app\'s notification inbox.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.titleSmall),
                    const SizedBox(height: 2),
                    Text(body, style: theme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (value == false) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onTurnOn,
              child: const Text('Turn on notifications'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.on,
    required this.locked,
    required this.onChanged,
  });

  final PushCategory category;
  final bool on;
  final bool locked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: locked || on,
      onChanged: locked ? null : onChanged,
      title: Text(category.name),
      subtitle: Text(
        locked
            ? '${category.description}. Always on, so nothing urgent is missed.'
            : category.description,
      ),
    );
  }
}
