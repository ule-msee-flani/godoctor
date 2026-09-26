import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/chat.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';

/// My post-consultation chats. Refreshes whenever a message arrives in any
/// of them (realtime), and every minute so "closes in" stays current.
final myChatsProvider = FutureProvider.autoDispose<List<ChatThread>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) return const [];
  final repo = ref.watch(chatRepositoryProvider);
  final sub = repo.watchAny().skip(1).listen((_) => ref.invalidateSelf());
  final timer = Timer(const Duration(minutes: 1), ref.invalidateSelf);
  ref.onDispose(() {
    sub.cancel();
    timer.cancel();
  });
  return repo.myChats();
});

/// Unread messages across all chats (tab badge).
final unreadChatsProvider = Provider.autoDispose<int>(
  (ref) =>
      ref
          .watch(myChatsProvider)
          .valueOrNull
          ?.fold<int>(0, (sum, c) => sum + c.unread) ??
      0,
);

/// Messages in one chat, live.
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, id) => ref.watch(chatRepositoryProvider).watchMessages(id),
    );
