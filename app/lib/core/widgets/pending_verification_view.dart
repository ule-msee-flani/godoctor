import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../services/live_updates.dart';
import '../theme/app_colors.dart';
import 'motion.dart';

/// Shown to doctors and pharmacies after they submit their registration,
/// until an admin approves it (a manual check with the regulator). They
/// get an email and a notification when it's done.
class PendingVerificationView extends ConsumerWidget {
  const PendingVerificationView({
    super.key,
    required this.title,
    required this.description,
    this.what = 'licence',
  });

  final String title;
  final String description;

  /// What's being checked: "licence" or "registration".
  final String what;

  Future<void> _checkAgain(BuildContext context, WidgetRef ref) async {
    ref
      ..invalidate(currentDoctorProfileProvider)
      ..invalidate(currentChemistProfileProvider);
    // The router opens the portal once approved.
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LiveRefresh(
          onRefresh: () => _checkAgain(context, ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(LucideIcons.logOut, size: 16),
                  label: const Text('Sign out'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                  ),
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Bobbing(
                  active: !reduceMotion(context),
                  height: 5,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: const BoxDecoration(
                      color: AppColors.warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.hourglass,
                      size: 46,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: text.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 28),
              _Step(
                state: _StepState.done,
                title: 'Registration submitted',
                body: 'We have your details and documents.',
              ),
              _Step(
                state: _StepState.now,
                title: 'We\'re checking your $what',
                body: 'This can take a few working days.',
              ),
              const _Step(
                state: _StepState.next,
                last: true,
                title: 'You\'re approved',
                body:
                    'We\'ll email you and send a notification, then your '
                    'portal opens.',
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: const Text('Check again'),
                onPressed: () => _checkAgain(context, ref),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.bellRing,
                    size: 14,
                    color: AppColors.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Keep notifications on so you don\'t miss the good news.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, now, next }

class _Step extends StatelessWidget {
  const _Step({
    required this.state,
    required this.title,
    required this.body,
    this.last = false,
  });

  final _StepState state;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = switch (state) {
      _StepState.done => AppColors.success,
      _StepState.now => AppColors.warning,
      _StepState.next => AppColors.borderStrong,
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: state == _StepState.next
                        ? AppColors.white
                        : color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: switch (state) {
                      _StepState.done => Icon(
                        LucideIcons.check,
                        size: 15,
                        color: color,
                      ),
                      _StepState.now => PulseDot(color: color, size: 9),
                      _StepState.next => const SizedBox.shrink(),
                    },
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: state == _StepState.done
                          ? AppColors.success
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 20, top: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: state == _StepState.next
                          ? AppColors.inkSoft
                          : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
