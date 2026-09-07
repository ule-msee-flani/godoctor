import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _historyProvider = FutureProvider((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(consultationRepositoryProvider).fetchHistoryForPatient(userId);
});

class ConsultationHistoryScreen extends ConsumerWidget {
  const ConsultationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation history')),
      body: history.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(
              message: 'No consultations yet.',
              icon: Icons.medical_services_outlined,
            );
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
                  trailing: c.status.name == 'requested' || c.status.name == 'matched'
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: (c.status.name == 'requested' || c.status.name == 'matched')
                      ? () => context.push('/patient/waiting/${c.id}')
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
