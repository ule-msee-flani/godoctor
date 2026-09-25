import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consultation.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';

/// The signed-in patient's upcoming (and in-progress) scheduled appointments.
final upcomingAppointmentsProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return const [];
      return ref
          .watch(appointmentRepositoryProvider)
          .upcomingForPatient(userId);
    });

/// The signed-in doctor's upcoming scheduled appointments.
final doctorUpcomingAppointmentsProvider =
    FutureProvider.autoDispose<List<Consultation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
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
final clockTickProvider = StreamProvider.autoDispose<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 20), (_) => DateTime.now()),
);
