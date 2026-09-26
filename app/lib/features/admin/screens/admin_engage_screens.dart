import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/support.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../support/support_screen.dart' show TicketTile;
import '../widgets/admin_ui.dart';

final _allTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).allTickets(),
);
final _ratingProvider =
    FutureProvider.autoDispose<({double average, int count})>(
      (ref) => ref.watch(supportRepositoryProvider).ratingSummary(),
    );

/// Help requests, complaints, feedback and deletion requests from every
/// user, plus how people rate the app.
class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  String? _status = 'open';
  SupportKind? _kind;

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(_allTicketsProvider);
    final rating = ref.watch(_ratingProvider).valueOrNull;
    final all = tickets.valueOrNull ?? const <SupportTicket>[];
    int count(bool Function(SupportTicket) f) => all.where(f).length;
    final shown = all
        .where((t) => _status == null || t.status == _status)
        .where((t) => _kind == null || t.kind == _kind)
        .toList();

    return AdminPage(
      title: 'Support',
      subtitle: 'Conversations with users. Replies notify them in the app.',
      onRefresh: () async {
        ref.invalidate(_allTicketsProvider);
        ref.invalidate(_ratingProvider);
      },
      children: [
        ResponsiveGrid(
          minWidth: 180,
          children: [
            StatTile(
              label: 'Waiting for a reply',
              value: '${count((t) => t.status == 'open')}',
              icon: LucideIcons.clock3,
            ),
            StatTile(
              label: 'Complaints',
              value: '${count((t) => t.kind == SupportKind.complaint)}',
              icon: LucideIcons.flag,
            ),
            StatTile(
              label: 'Deletion requests',
              value:
                  '${count((t) => t.kind == SupportKind.accountDeletion && t.status != 'closed')}',
              icon: LucideIcons.trash2,
            ),
            StatTile(
              label: 'App rating',
              value: rating == null || rating.count == 0
                  ? '—'
                  : '${rating.average.toStringAsFixed(1)} / 5',
              icon: LucideIcons.star,
              caption: rating == null ? null : '${rating.count} ratings',
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            FilterRow<String>(
              value: _status,
              allLabel: 'Any status',
              options: const [
                ('open', 'Waiting'),
                ('answered', 'Replied'),
                ('closed', 'Closed'),
              ],
              onChanged: (v) => setState(() => _status = v),
            ),
            FilterRow<SupportKind>(
              value: _kind,
              allLabel: 'All kinds',
              options: [for (final k in SupportKind.values) (k, k.label)],
              onChanged: (v) => setState(() => _kind = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        tickets.when(
          loading: () => const SizedBox(height: 200, child: LoadingView()),
          error: (e, _) => ErrorView(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(_allTicketsProvider),
          ),
          data: (_) => shown.isEmpty
              ? const EmptyView(
                  message: 'Nothing here.',
                  icon: LucideIcons.inbox,
                )
              : Column(
                  children: [
                    for (final t in shown)
                      TicketTile(ticket: t, route: '/admin/support/${t.id}'),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Send an in-app announcement to everyone or to one group.
class AdminBroadcastScreen extends ConsumerStatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  ConsumerState<AdminBroadcastScreen> createState() =>
      _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends ConsumerState<AdminBroadcastScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _role;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final audience = switch (_role) {
      'patient' => 'all patients',
      'doctor' => 'all doctors',
      'chemist' => 'all chemists',
      _ => 'everyone',
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send to $audience?'),
        content: Text(
          '"${_title.text.trim()}" will appear in their notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final n = await ref
          .read(adminRepositoryProvider)
          .broadcast(
            role: _role,
            title: _title.text.trim(),
            body: _body.text.trim(),
          );
      if (!mounted) return;
      _title.clear();
      _body.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Announcement sent to $n people')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AdminPage(
      title: 'Announcements',
      subtitle:
          'Send an in-app notification to users. Suspended accounts are skipped.',
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Who should get it?', style: theme.titleSmall),
                const SizedBox(height: 8),
                FilterRow<String>(
                  value: _role,
                  allLabel: 'Everyone',
                  options: const [
                    ('patient', 'Patients'),
                    ('doctor', 'Doctors'),
                    ('chemist', 'Chemists'),
                  ],
                  onChanged: (v) => setState(() => _role = v),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 120,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _body,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: _title.text.trim().isEmpty || _sending
                        ? null
                        : _send,
                    icon: const Icon(LucideIcons.megaphone, size: 18),
                    label: Text(_sending ? 'Sending…' : 'Send announcement'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
