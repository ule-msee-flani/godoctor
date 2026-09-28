import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/family.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../family/family_providers.dart';
import '../../../services/live_updates.dart';

const kRelationships = [
  'Parent',
  'Child',
  'Spouse',
  'Sibling',
  'Grandparent',
  'Relative',
  'Guardian',
  'Friend',
];

/// Profile › Family: people who can join your consultations as listeners
/// ("family sessions"). Each family member has their own GoDoctor account.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, [
    String? done,
  ]) async {
    try {
      await action();
      ref.invalidate(familyProvider);
      if (done != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final family = ref.watch(familyProvider);
    final repo = ref.read(familyRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final invited = await showDialog<bool>(
            context: context,
            builder: (_) => const _InviteDialog(),
          );
          if (invited == true) ref.invalidate(familyProvider);
        },
        icon: const Icon(LucideIcons.userPlus),
        label: const Text('Invite family'),
      ),
      body: LiveRefresh(
        onRefresh: () => ref.refresh(familyProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySofter,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.headphones, color: AppColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Family sessions', style: theme.titleSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Like bringing someone into the doctor\'s room: when you see a '
                          'doctor, you can invite a family member who is online to join '
                          'the video call and listen in.',
                          style: theme.bodySmall?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            family.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Column(
                  children: [
                    Skeleton(height: 64),
                    SizedBox(height: 10),
                    Skeleton(height: 64),
                  ],
                ),
              ),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(familyProvider),
              ),
              data: (members) {
                final forMe = members.where((m) => m.awaitsMyAnswer).toList();
                final linked = members.where((m) => m.isAccepted).toList();
                final waiting = members
                    .where((m) => m.status == 'pending' && m.invitedByMe)
                    .toList();
                final declined = members
                    .where((m) => m.status == 'declined' && m.invitedByMe)
                    .toList();

                if (members.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: EmptyView(
                      message:
                          'No family members yet.\nInvite them with the email or phone number they use on GoDoctor.',
                      icon: LucideIcons.users,
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (forMe.isNotEmpty) ...[
                      const _Label('Invitations for you'),
                      for (final m in forMe)
                        _MemberCard(
                          member: m,
                          subtitle: 'Wants to add you as family',
                          actions: [
                            TextButton(
                              onPressed: () => _run(
                                context,
                                ref,
                                () => repo.respond(m.linkId, accept: false),
                              ),
                              child: const Text('Decline'),
                            ),
                            FilledButton(
                              onPressed: () => _run(
                                context,
                                ref,
                                () => repo.respond(m.linkId, accept: true),
                                '${m.name} added to your family',
                              ),
                              child: const Text('Accept'),
                            ),
                          ],
                        ),
                    ],
                    if (linked.isNotEmpty) ...[
                      _Label('Your family (${linked.length})'),
                      for (final m in linked)
                        _MemberCard(
                          member: m,
                          subtitle: [
                            if (m.invitedByMe) m.relationship,
                            m.online ? 'Online now' : 'Offline',
                          ].join(' · '),
                          onRemove: () => _confirmRemove(context, ref, m),
                        ),
                    ],
                    if (waiting.isNotEmpty) ...[
                      const _Label('Waiting for them to accept'),
                      for (final m in waiting)
                        _MemberCard(
                          member: m,
                          subtitle: '${m.relationship} · invitation sent',
                          actions: [
                            TextButton(
                              onPressed: () => _run(
                                context,
                                ref,
                                () => repo.remove(m.linkId),
                                'Invitation cancelled',
                              ),
                              child: const Text('Cancel invitation'),
                            ),
                          ],
                        ),
                    ],
                    if (declined.isNotEmpty) ...[
                      const _Label('Declined'),
                      for (final m in declined)
                        _MemberCard(
                          member: m,
                          subtitle: 'Declined your invitation',
                          onRemove: () =>
                              _run(context, ref, () => repo.remove(m.linkId)),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    FamilyMember m,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${m.name}?'),
        content: const Text(
          'They will no longer be able to join your consultations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(
        context,
        ref,
        () => ref.read(familyRepositoryProvider).remove(m.linkId),
        '${m.name} removed',
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.inkSoft,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.subtitle,
    this.actions = const [],
    this.onRemove,
  });

  final FamilyMember member;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: member.name,
                  path: member.avatarUrl,
                  online: member.isAccepted && member.online,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: theme.titleSmall),
                      Text(
                        subtitle,
                        style: theme.bodySmall?.copyWith(
                          color: member.isAccepted && member.online
                              ? AppColors.success
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(LucideIcons.userX, size: 18),
                    onPressed: onRemove,
                  ),
              ],
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  const _InviteDialog();

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _contact = TextEditingController();
  String _relationship = kRelationships.first;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_contact.text.trim().isEmpty) {
      setState(() => _error = 'Enter their email or phone number.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(familyRepositoryProvider)
          .invite(contact: _contact.text.trim(), relationship: _relationship);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent. They will see it in the app.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('Invite a family member'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'They need a GoDoctor account. Enter the email or phone number they sign in with.',
                style: theme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email or phone',
                  hintText: 'name@example.com or 0712 345 678',
                ),
              ),
              const SizedBox(height: 16),
              Text('They are your…', style: theme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in kRelationships)
                    ChoiceChip(
                      label: Text(r),
                      selected: _relationship == r,
                      onSelected: (_) => setState(() => _relationship = r),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: Text(_sending ? 'Sending…' : 'Send invitation'),
        ),
      ],
    );
  }
}
