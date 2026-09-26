import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/family.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import 'family_providers.dart';

/// "Family session": invite family members who are online to join this
/// consultation and listen in. Shown while paying and during the call.
class FamilySessionPanel extends ConsumerStatefulWidget {
  const FamilySessionPanel({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<FamilySessionPanel> createState() => _FamilySessionPanelState();
}

class _FamilySessionPanelState extends ConsumerState<FamilySessionPanel> {
  final Set<String> _busy = {};

  Future<void> _toggle(FamilyMember m, SessionPerson? inSession) async {
    setState(() => _busy.add(m.userId));
    final repo = ref.read(familyRepositoryProvider);
    try {
      if (inSession == null ||
          inSession.status == 'declined' ||
          inSession.status == 'left') {
        await repo.inviteToConsultation(widget.consultationId, m.userId);
      } else {
        await repo.removeFromConsultation(widget.consultationId, m.userId);
      }
      ref.invalidate(sessionPeopleProvider(widget.consultationId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(m.userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final family = ref.watch(familyProvider).valueOrNull ?? const [];
    final people =
        ref.watch(sessionPeopleProvider(widget.consultationId)).valueOrNull ??
        const <SessionPerson>[];
    final accepted = family.where((m) => m.isAccepted).toList()
      ..sort((a, b) => (b.online ? 1 : 0) - (a.online ? 1 : 0));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.headphones,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text('Family session', style: theme.titleSmall)),
              Text('Optional', style: theme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Invite a family member who is online to join the call and listen in.',
            style: theme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (accepted.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/patient/profile/family'),
                icon: const Icon(LucideIcons.userPlus, size: 16),
                label: const Text('Add family members'),
              ),
            )
          else
            for (final m in accepted)
              _Row(
                member: m,
                inSession: people
                    .where((p) => p.isFamily && p.userId == m.userId)
                    .firstOrNull,
                busy: _busy.contains(m.userId),
                onTap: (inSession) => _toggle(m, inSession),
              ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.member,
    required this.inSession,
    required this.busy,
    required this.onTap,
  });

  final FamilyMember member;
  final SessionPerson? inSession;
  final bool busy;
  final ValueChanged<SessionPerson?> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final status = inSession?.status;
    final active = status == 'invited' || status == 'joined';
    final (label, color) = switch (status) {
      'joined' => ('Listening now', AppColors.success),
      'invited' => ('Invited, waiting', AppColors.warning),
      'declined' => ('Declined', AppColors.inkFaint),
      'left' => ('Left the call', AppColors.inkFaint),
      _ =>
        member.online
            ? ('Online now', AppColors.success)
            : ('Offline', AppColors.inkFaint),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          UserAvatar(
            name: member.name,
            path: member.avatarUrl,
            radius: 20,
            online: member.online,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: theme.titleSmall),
                Text(
                  label,
                  style: theme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : active
              ? TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => onTap(inSession),
                  child: const Text('Remove'),
                )
              : FilledButton.tonal(
                  // Compact: the patient theme makes buttons full-width.
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: () => onTap(inSession),
                  child: const Text('Invite'),
                ),
        ],
      ),
    );
  }
}
