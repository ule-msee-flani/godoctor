import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _historyProvider = FutureProvider((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref
      .watch(consultationRepositoryProvider)
      .fetchHistoryForPatient(userId);
});

class ConsultationHistoryScreen extends StatelessWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Consultation history')),
    body: const ConsultationHistoryList(),
  );
}

/// The list itself, reused by the Activity tab.
class ConsultationHistoryList extends ConsumerWidget {
  const ConsultationHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_historyProvider);
    return history.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            message: 'No consultations yet.',
            icon: LucideIcons.stethoscope,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = list[i];
            final scheduled = c.isScheduled && c.scheduledFor != null;
            final route = c.isScheduled
                ? '/patient/appointment/${c.id}'
                : '/patient/waiting/${c.id}';
            final statusLabel = c.status.name == 'inProgress'
                ? 'in progress'
                : c.status.name;
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push(route),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentTealSoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Center(
                          child: Icon(
                            scheduled
                                ? LucideIcons.calendarClock
                                : LucideIcons.stethoscope,
                            color: AppColors.accentTeal,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.specialtyRequested,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              scheduled
                                  ? '${formatDateTime(c.scheduledFor!)} · $statusLabel'
                                  : '$statusLabel · ${formatDayShort(c.createdAt.toLocal())}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        color: AppColors.inkFaint,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
