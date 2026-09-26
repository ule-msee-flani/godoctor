import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/family.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

/// My family links (accepted, pending either way). Refreshes every 30 s so
/// the "online" dots stay roughly current.
final familyProvider = FutureProvider.autoDispose<List<FamilyMember>>((ref) {
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(familyRepositoryProvider).myFamily();
});

/// Invitations waiting for my answer (for badges).
final pendingFamilyInvitesProvider = Provider.autoDispose<int>(
  (ref) =>
      ref
          .watch(familyProvider)
          .valueOrNull
          ?.where((m) => m.awaitsMyAnswer)
          .length ??
      0,
);

/// Everyone in a consultation (patient, doctor, family), live.
final sessionPeopleProvider = StreamProvider.autoDispose
    .family<List<SessionPerson>, String>(
      (ref, consultationId) =>
          ref.watch(familyRepositoryProvider).watchPeople(consultationId),
    );

/// Consultations I've been invited to listen in on.
final myFamilySessionInvitesProvider = StreamProvider.autoDispose<List<String>>(
  (ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return Stream.value(const []);
    return ref.watch(familyRepositoryProvider).watchMyInvites(userId);
  },
);

/// Tells the server "I'm online" once a minute while the patient app is
/// open, so family can see who is available to join a session.
final presenceHeartbeatProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return;
  final repo = ref.watch(profileRepositoryProvider);
  void ping() => repo.touchPresence().catchError((_) {});
  ping();
  final timer = Timer.periodic(const Duration(seconds: 60), (_) => ping());
  ref.onDispose(timer.cancel);
});
