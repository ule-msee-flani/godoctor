import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/models/chat.dart';
import '../../data/repositories/repository_errors.dart';
import 'chat_providers.dart';
import '../../core/widgets/motion.dart';
import '../../services/live_updates.dart';

/// "Closes in 5 h" / "Closes in 20 min" / "Closed".
String chatWindowLabel(DateTime? closesAt, {DateTime? now}) {
  if (closesAt == null) return 'Closed';
  final left = closesAt.difference(now ?? DateTime.now());
  if (left.isNegative) return 'Closed';
  if (left.inHours >= 1) return 'Closes in ${left.inHours} h';
  return 'Closes in ${left.inMinutes.clamp(1, 59)} min';
}

/// Short time for a chat list: "14:05" today, else "Tue 26 Sep".
String chatTime(DateTime t, {DateTime? now}) =>
    isSameDay(t, now ?? DateTime.now()) ? formatTime(t) : formatDayShort(t);

/// Chats: after every consultation, patient and doctor can message each
/// other free for 24 hours (e.g. "the chemist doesn't have this medicine").
class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key, required this.doctor});

  /// Doctor's view (routes to /doctor/chat/..).
  final bool doctor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(myChatsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: chats.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(myChatsProvider),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyView(
              icon: LucideIcons.messagesSquare,
              message: doctor
                  ? 'After each consultation your patient can message you '
                        'free for 24 hours. Those chats appear here.'
                  : 'After a consultation you can message your doctor free '
                        'for 24 hours, for example if the chemist doesn\'t '
                        'have a medicine. Your chats appear here.',
            );
          }
          final open = list.where((c) => c.isOpen).toList();
          final closed = list.where((c) => !c.isOpen).toList();
          return LiveRefresh(
            onRefresh: () => ref.refresh(myChatsProvider.future),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (open.isNotEmpty) const _Header('Open now'),
                for (final (i, c) in open.indexed)
                  FadeSlideIn(
                    index: i,
                    child: _ChatRow(thread: c, doctor: doctor),
                  ),
                if (closed.isNotEmpty) const _Header('Closed'),
                for (final (i, c) in closed.indexed)
                  FadeSlideIn(
                    index: open.length + i,
                    child: _ChatRow(thread: c, doctor: doctor),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.thread, required this.doctor});

  final ChatThread thread;
  final bool doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = thread;
    final preview = c.lastBody == null
        ? c.symptoms
        : c.lastFromMe
        ? 'You: ${c.lastBody}'
        : c.lastBody!;
    final unread = c.unread > 0;
    return InkWell(
      onTap: () => context.push(
        doctor
            ? '/doctor/chat/${c.consultationId}'
            : '/patient/chat/${c.consultationId}',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Opacity(
              opacity: c.isOpen ? 1 : 0.6,
              child: UserAvatar(
                name: c.otherName,
                path: c.otherAvatar,
                radius: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleSmall,
                        ),
                      ),
                      if (c.lastAt != null)
                        Text(
                          chatTime(c.lastAt!),
                          style: theme.bodySmall?.copyWith(
                            color: unread ? AppColors.primary : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall?.copyWith(
                            color: unread ? AppColors.ink : null,
                            fontWeight: unread ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${c.unread}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${c.specialty} · ${formatDayShort(c.consultedAt)} · '
                    '${chatWindowLabel(c.closesAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(
                      color: c.isOpen ? AppColors.success : AppColors.inkFaint,
                      fontSize: 11.5,
                    ),
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
