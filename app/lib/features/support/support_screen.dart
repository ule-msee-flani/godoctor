import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/support.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'rate_app_sheet.dart';

final myTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).myTickets(),
);

/// Support & feedback home (every role): start a conversation with the
/// support team, send feedback, report a complaint or rate the app; and
/// see earlier conversations.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final tickets = ref.watch(myTicketsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Support & feedback')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myTicketsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text('How can we help?', style: theme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Our support team replies here in the app. You will get a notification.',
              style: theme.bodyMedium,
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _Action(
                  icon: LucideIcons.headset,
                  label: 'Get help',
                  color: AppColors.primary,
                  onTap: () =>
                      context.push('/account/support/new?kind=support'),
                ),
                _Action(
                  icon: LucideIcons.flag,
                  label: 'Report a complaint',
                  color: AppColors.danger,
                  onTap: () =>
                      context.push('/account/support/new?kind=complaint'),
                ),
                _Action(
                  icon: LucideIcons.messageSquareHeart,
                  label: 'Give feedback',
                  color: AppColors.accentTeal,
                  onTap: () =>
                      context.push('/account/support/new?kind=feedback'),
                ),
                _Action(
                  icon: LucideIcons.star,
                  label: 'Rate GoDoctor',
                  color: AppColors.warning,
                  onTap: () => showRateAppSheet(context),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('Your conversations', style: theme.titleMedium),
            const SizedBox(height: 10),
            tickets.when(
              loading: () => const Skeleton(height: 64),
              error: (e, _) => ErrorView(message: friendlyError(e)),
              data: (list) => list.isEmpty
                  ? Text(
                      'Nothing yet. Start one above.',
                      style: theme.bodyMedium,
                    )
                  : Column(
                      children: [for (final t in list) TicketTile(ticket: t)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One conversation in a list (also used by the admin inbox).
class TicketTile extends StatelessWidget {
  const TicketTile({super.key, required this.ticket, this.route});

  final SupportTicket ticket;

  /// Where tapping goes; defaults to the user's own thread.
  final String? route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final (label, color) = switch (ticket.status) {
      'answered' => ('Replied', AppColors.success),
      'closed' => ('Closed', AppColors.inkFaint),
      _ => ('Waiting', AppColors.warning),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => context.push(route ?? '/account/support/${ticket.id}'),
        leading: Icon(switch (ticket.kind) {
          SupportKind.complaint => LucideIcons.flag,
          SupportKind.feedback => LucideIcons.messageSquareHeart,
          SupportKind.accountDeletion => LucideIcons.trash2,
          SupportKind.support => LucideIcons.headset,
        }, color: AppColors.inkSoft),
        title: Text(
          ticket.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${ticket.kind.label} · ${formatDateTime(ticket.lastMessageAt)}',
        ),
        trailing: Text(
          label,
          style: theme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
