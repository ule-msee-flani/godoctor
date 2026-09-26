import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/video_call_panel.dart';
import '../../../data/models/family.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

/// What I (an invited family member) may see about the consultation;
/// re-checked every few seconds so "join" lights up when the call starts.
final _infoProvider = FutureProvider.autoDispose
    .family<FamilySessionInfo?, String>((ref, id) {
      final timer = Timer(const Duration(seconds: 5), ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return ref.watch(familyRepositoryProvider).sessionInfo(id);
    });

/// A family member's view of a consultation they were invited to: join and
/// listen in on the (mock) video call, or leave. They see who is on the call
/// but never the patient's notes or prescriptions.
class FamilySessionScreen extends ConsumerStatefulWidget {
  const FamilySessionScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<FamilySessionScreen> createState() =>
      _FamilySessionScreenState();
}

class _FamilySessionScreenState extends ConsumerState<FamilySessionScreen> {
  bool _busy = false;

  Future<void> _respond({required bool join}) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(familyRepositoryProvider)
          .respondToSession(widget.consultationId, join: join);
      ref.invalidate(_infoProvider(widget.consultationId));
      if (!join && mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final info = ref.watch(_infoProvider(widget.consultationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Family session')),
      body: switch (info) {
        AsyncData(value: null) => const EmptyView(
          message: 'This invitation is no longer available.',
          icon: LucideIcons.userX,
        ),
        AsyncData(value: final i?) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            if (i.myStatus == 'joined' && i.isLive) ...[
              VideoCallPanel(
                otherPartyName: i.doctorName ?? 'Doctor',
                otherPartyRole: '${i.specialty} · with ${i.patientName}',
                startedAt: i.startedAt,
                height: 300,
                onEndCall: _busy ? null : () => _respond(join: false),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    LucideIcons.headphones,
                    size: 18,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You are listening in on ${i.patientName}\'s consultation. '
                      'Your microphone starts muted.',
                      style: theme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySofter,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    const Icon(
                      LucideIcons.headphones,
                      size: 36,
                      color: AppColors.ink,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${i.patientName} invited you to their consultation',
                      textAlign: TextAlign.center,
                      style: theme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        i.specialty,
                        if (i.doctorName != null) 'with ${i.doctorName}',
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    if (i.isOver)
                      Text(
                        'This consultation has ended.',
                        style: theme.bodyMedium,
                      )
                    else if (i.myStatus == 'declined' || i.myStatus == 'left')
                      Text('You left this session.', style: theme.bodyMedium)
                    else if (!i.isLive)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Waiting for the consultation to start…',
                              style: theme.bodyMedium,
                            ),
                          ),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _respond(join: true),
                        icon: const Icon(LucideIcons.video, size: 18),
                        label: const Text('Join and listen'),
                      ),
                    if (!i.isOver && i.myStatus == 'invited') ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy ? null : () => _respond(join: false),
                        child: const Text('Not now'),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        AsyncError(:final error) => ErrorView(message: friendlyError(error)),
        _ => const LoadingView(),
      },
    );
  }
}

/// Banner on the patient home screen when a family member has invited me to
/// listen in on their consultation.
class FamilyInviteBanner extends ConsumerWidget {
  const FamilyInviteBanner({super.key, required this.consultationIds});

  final List<String> consultationIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (consultationIds.isEmpty) return const SizedBox.shrink();
    final id = consultationIds.first;
    final info = ref.watch(_infoProvider(id)).valueOrNull;
    if (info == null || info.isOver) return const SizedBox.shrink();
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/patient/family-session/$id'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.headphones, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.myStatus == 'joined'
                            ? 'You are in ${info.patientName}\'s consultation'
                            : '${info.patientName} invited you to a consultation',
                        style: theme.titleSmall,
                      ),
                      Text(
                        info.isLive
                            ? 'Tap to join and listen in'
                            : 'It starts soon. Tap to see details.',
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.success),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
