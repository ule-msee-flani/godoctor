import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _doctorHistoryProvider = FutureProvider((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref
      .watch(consultationRepositoryProvider)
      .fetchHistoryForDoctor(userId);
});

class DoctorHistoryScreen extends ConsumerWidget {
  const DoctorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_doctorHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation history')),
      body: history.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(message: 'No consultations yet.');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              return Card(
                child: ListTile(
                  title: Text(c.specialtyRequested),
                  subtitle: Text(
                    '${c.status.name} · ${c.createdAt.toLocal().toString().split(' ').first}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
