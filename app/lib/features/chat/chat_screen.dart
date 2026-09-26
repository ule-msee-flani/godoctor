import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/chat.dart';
import '../../data/models/consultation.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/appointment_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/prescription_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'chat_providers.dart';
import 'chats_screen.dart';

const _patientQuickReplies = [
  'The chemist doesn\'t have this medicine',
  'I think I\'m having a side effect',
  'I\'m feeling better, thank you',
  'I have a question about the dose',
];

const _doctorQuickReplies = [
  'How are you feeling today?',
  'Try the chemist suggested in the app',
  'I\'ve sent you a new prescription',
  'Please book a follow-up consultation',
];

/// The free 24-hour chat after a consultation. A pinned card at the top
/// shows what it's about (symptoms, medicines prescribed); after 24 hours
/// it becomes read-only.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.consultationId,
    required this.doctor,
  });

  final String consultationId;

  /// Doctor's view (can send a new prescription from here).
  final bool doctor;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _text = TextEditingController();
  bool _sending = false;

  String get _id => widget.consultationId;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    _markRead();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await ref.read(chatRepositoryProvider).markRead(_id);
      ref.invalidate(myChatsProvider);
    } catch (_) {}
  }

  Future<void> _send([String? preset]) async {
    final body = (preset ?? _text.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(chatRepositoryProvider).send(_id, body);
      HapticFeedback.selectionClick();
      if (preset == null) _text.clear();
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
    ref.listen(chatMessagesProvider(_id), (prev, next) {
      final before = prev?.valueOrNull?.length ?? 0;
      if ((next.valueOrNull?.length ?? 0) > before) _markRead();
    });
    ref.watch(clockTickProvider); // "closes in" and closing on time
    final me = ref.watch(currentUserIdProvider);
    final consultation = ref.watch(appointmentProvider(_id)).valueOrNull;
    final thread = ref
        .watch(myChatsProvider)
        .valueOrNull
        ?.where((t) => t.consultationId == _id)
        .firstOrNull;
    final messages = ref.watch(chatMessagesProvider(_id));
    final prescriptions =
        ref.watch(consultationPrescriptionsProvider(_id)).valueOrNull ??
        const <Prescription>[];

    final closesAt = consultation?.chatClosesAt ?? thread?.closesAt;
    final open = closesAt != null && closesAt.isAfter(DateTime.now());
    final otherName =
        thread?.otherName ?? (widget.doctor ? 'Patient' : 'Your doctor');
    final theme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(name: otherName, path: thread?.otherAvatar, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleMedium,
                  ),
                  Text(
                    closesAt == null && consultation == null
                        ? ''
                        : chatWindowLabel(closesAt),
                    style: theme.bodySmall?.copyWith(
                      color: open ? AppColors.success : AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.doctor && open)
            IconButton(
              tooltip: 'New prescription',
              icon: const Icon(LucideIcons.clipboardPlus),
              onPressed: () => context.push('/doctor/chat/$_id/prescribe'),
            ),
        ],
      ),
      body: Column(
        children: [
          _ContextCard(
            consultation: consultation,
            thread: thread,
            prescriptions: prescriptions,
            doctor: widget.doctor,
          ),
          Expanded(
            child: messages.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: friendlyError(e)),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        open
                            ? widget.doctor
                                  ? 'No messages yet. The patient can write to you here until the chat closes.'
                                  : 'Ask your doctor anything about this visit. The chat is free and stays open for 24 hours after the consultation.'
                            : 'No messages were sent in this chat.',
                        textAlign: TextAlign.center,
                        style: theme.bodyMedium,
                      ),
                    ),
                  );
                }
                final reversed = list.reversed.toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: reversed.length,
                  itemBuilder: (context, i) {
                    final m = reversed[i];
                    final older = i + 1 < reversed.length
                        ? reversed[i + 1]
                        : null;
                    final showDay =
                        older == null ||
                        !isSameDay(older.createdAt, m.createdAt);
                    return Column(
                      children: [
                        if (showDay) _DayLabel(day: m.createdAt),
                        _Bubble(message: m, mine: m.senderId == me),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (open)
            _Composer(
              controller: _text,
              sending: _sending,
              quickReplies: widget.doctor
                  ? _doctorQuickReplies
                  : _patientQuickReplies,
              onSend: _send,
            )
          else if (consultation != null || thread != null)
            _ClosedBar(
              doctor: widget.doctor,
              onBook: () => context.push('/patient/intake'),
            ),
        ],
      ),
    );
  }
}

/// Pinned at the top: which consultation this chat is about.
class _ContextCard extends StatefulWidget {
  const _ContextCard({
    required this.consultation,
    required this.thread,
    required this.prescriptions,
    required this.doctor,
  });

  final Consultation? consultation;
  final ChatThread? thread;
  final List<Prescription> prescriptions;
  final bool doctor;

  @override
  State<_ContextCard> createState() => _ContextCardState();
}

class _ContextCardState extends State<_ContextCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = widget.consultation;
    final symptoms = c?.symptomSummary ?? widget.thread?.symptoms ?? '';
    final specialty = c?.specialtyRequested ?? widget.thread?.specialty ?? '';
    final when =
        c?.startedAt?.toLocal() ??
        c?.createdAt.toLocal() ??
        widget.thread?.consultedAt;
    final items = [for (final p in widget.prescriptions) ...p.items];

    return Material(
      color: AppColors.primarySofter,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.video,
                      size: 15,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        [
                          'From your video consultation',
                          if (when != null) formatDayShort(when),
                        ].join(' · '),
                        style: theme.labelMedium,
                      ),
                    ),
                    Icon(
                      _expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 18,
                      color: AppColors.inkSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [specialty, symptoms].where((s) => s.isNotEmpty).join(': '),
                  maxLines: _expanded ? 6 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(color: AppColors.ink),
                ),
                if (!_expanded && items.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Prescribed: ${items.map((i) => i.displayName).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall,
                    ),
                  ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Text('Medicines prescribed', style: theme.labelMedium),
                  const SizedBox(height: 4),
                  if (items.isEmpty)
                    Text('None', style: theme.bodySmall)
                  else
                    for (final i in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                LucideIcons.pill,
                                size: 14,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                [
                                  i.displayName,
                                  if (i.dosage?.isNotEmpty ?? false) i.dosage!,
                                  'Qty ${i.quantity}',
                                ].join(' · '),
                                style: theme.bodySmall?.copyWith(
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  if (c?.summaryForPatient != null) ...[
                    const SizedBox(height: 8),
                    Text('Doctor\'s summary', style: theme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      c!.summaryForPatient!,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(color: AppColors.ink),
                    ),
                  ],
                  if (!widget.doctor && c != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => context.push('/patient/visit/${c.id}'),
                        icon: const Icon(LucideIcons.clipboardList, size: 16),
                        label: const Text('Open visit summary'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final label = isSameDay(day, now)
        ? 'Today'
        : isSameDay(day, now.subtract(const Duration(days: 1)))
        ? 'Yesterday'
        : formatDayShort(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.fileCheck,
                  size: 14,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.body,
                    style: theme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.white,
            border: mine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: Text(
                  message.body,
                  style: theme.bodyMedium?.copyWith(
                    color: mine ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatTime(message.createdAt),
                style: TextStyle(
                  fontSize: 10.5,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.quickReplies,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final List<String> quickReplies;
  final Future<void> Function([String? preset]) onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controller.text.isEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                  children: [
                    for (final q in quickReplies) ...[
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(q),
                        onPressed: sending ? null : () => onSend(q),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                        isDense: true,
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: 'Send',
                    onPressed: controller.text.trim().isEmpty || sending
                        ? null
                        : () => onSend(),
                    icon: const Icon(LucideIcons.sendHorizontal, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosedBar extends StatelessWidget {
  const _ClosedBar({required this.doctor, required this.onBook});

  final bool doctor;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.lock,
                    size: 16,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This chat closed 24 hours after the consultation.',
                      style: theme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (!doctor) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: onBook,
                  icon: const Icon(LucideIcons.stethoscope, size: 18),
                  label: const Text('Book another consultation'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
