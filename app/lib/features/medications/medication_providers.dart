import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/medication.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/repository_providers.dart';
import '../../services/live_updates.dart';

/// My medicine courses with reminders switched on.
final activeSchedulesProvider =
    FutureProvider.autoDispose<List<MedicationSchedule>>((ref) {
      ref.watch(liveTick(LiveTable.schedules));
      ref.watch(liveTick(LiveTable.doses));
      if (ref.watch(currentUserIdProvider) == null) return const [];
      return ref
          .watch(medicationRepositoryProvider)
          .mySchedules(activeOnly: true)
          .then(
            (list) => [
              // A course that has finished drops off by itself.
              for (final s in list)
                if (!s.endOn.isBefore(_today())) s,
            ],
          );
    });

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
