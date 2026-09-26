import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/support.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'support_screen.dart' show myTicketsProvider;

final _ticketProvider = FutureProvider.autoDispose
    .family<SupportTicket?, String>(
      (ref, id) => ref.watch(supportRepositoryProvider).ticket(id),
    );

final _messagesProvider = StreamProvider.autoDispose
    .family<List<SupportMessage>, String>(
      (ref, id) => ref.watch(supportRepositoryProvider).watchMessages(id),
    );

/// One support conversation. Users see their own; admins ([asStaff]) reply
/// as "GoDoctor support".
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.ticketId, this.asStaff = false});

  final String ticketId;
  final bool asStaff;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .send(widget.ticketId, text, asStaff: widget.asStaff);
      _input.clear();
      ref.invalidate(_ticketProvider(widget.ticketId));
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

  Future<void> _close() async {
    try {
      await ref.read(supportRepositoryProvider).close(widget.ticketId);
      ref.invalidate(_ticketProvider(widget.ticketId));
      ref.invalidate(myTicketsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final ticket = ref.watch(_ticketProvider(widget.ticketId)).valueOrNull;
    final messages = ref.watch(_messagesProvider(widget.ticketId));
    final closed = ticket?.isClosed ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket?.subject ?? 'Conversation'),
        actions: [
          if (ticket != null && !closed)
            TextButton(
              onPressed: _close,
              child: Text(widget.asStaff ? 'Close ticket' : 'Mark solved'),
            ),
        ],
      ),
      body: Column(
        children: [
          if (ticket != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primarySofter,
              child: Text(
                [
                  ticket.kind.label,
                  'opened ${formatDateTime(ticket.createdAt)}',
                  if (ticket.relatedConsultationId != null)
                    'about a consultation',
                  if (ticket.relatedOrderId != null) 'about an order',
                ].join(' · '),
                style: theme.bodySmall,
              ),
            ),
          Expanded(
            child: messages.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: friendlyError(e)),
              data: (list) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: list.length + 1,
                itemBuilder: (context, i) {
                  if (i == list.length) {
                    // Oldest end (top): a note on what happens next.
                    return widget.asStaff
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Our support team will reply here. You will also get a notification.',
                              textAlign: TextAlign.center,
                              style: theme.bodySmall,
                            ),
                          );
                  }
                  final m = list[list.length - 1 - i];
                  final mine = m.fromStaff == widget.asStaff;
                  return _Bubble(message: m, mine: mine);
                },
              ),
            ),
          ),
          if (closed)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'This conversation is closed. Start a new one from Support if you need more help.',
                textAlign: TextAlign.center,
                style: theme.bodySmall,
              ),
            )
          else
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: widget.asStaff
                              ? 'Reply as GoDoctor support'
                              : 'Write a message',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Send',
                      onPressed: _sending ? null : _send,
                      icon: const Icon(LucideIcons.sendHorizontal, size: 18),
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final SupportMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
            border: mine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.fromStaff && !mine)
                Text(
                  'GoDoctor support',
                  style: theme.labelSmall?.copyWith(color: AppColors.primary),
                ),
              Text(
                message.body,
                style: theme.bodyMedium?.copyWith(
                  color: mine ? Colors.white : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTime(message.createdAt),
                style: theme.labelSmall?.copyWith(
                  color: mine ? Colors.white70 : AppColors.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
