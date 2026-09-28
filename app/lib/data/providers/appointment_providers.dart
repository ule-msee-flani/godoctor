import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consultation.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import '../../services/live_updates.dart';

/// The signed-in patient's upcoming (and in-progress) scheduled appointments.
final upcomingAppointmentsProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      ref.watch(liveTick(LiveTable.consultations));
      if (userId == null) return const [];
      return ref
          .watch(appointmentRepositoryProvider)
          .upcomingForPatient(userId);
    });

/// The signed-in doctor's upcoming scheduled appointments.
final doctorUpcomingAppointmentsProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      ref.watch(liveTick(LiveTable.consultations));
      if (userId == null) return const [];
      return ref.watch(appointmentRepositoryProvider).upcomingForDoctor(userId);
    });

/// Live view of one consultation/appointment (status changes as it happens).
final appointmentProvider = StreamProvider.autoDispose
    .family<Consultation?, String>(
      (ref, id) =>
          ref.watch(consultationRepositoryProvider).watchConsultation(id),
    );

/// Ticks every 20s so time-dependent UI ("Join" appearing 10 minutes before
/// the start) updates without the user doing anything.
final clockTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  final timer = Timer.periodic(
    const Duration(seconds: 20),
    (_) => controller.add(DateTime.now()),
  );
  // Stop ticking as soon as no screen is listening any more.
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});
