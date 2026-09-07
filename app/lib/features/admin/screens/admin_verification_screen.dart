import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/repository_providers.dart';

final _pendingDoctorsProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).fetchPendingDoctors(),
);
final _pendingChemistsProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).fetchPendingChemists(),
);

/// Manual doctor/chemist verification queue. Per spec, doctor license
/// verification is a human checking the public KMPDC register for v1 -- no
/// automated integration. This screen is just the approve/reject UI on top
/// of that manual check.
class AdminVerificationScreen extends ConsumerWidget {
  const AdminVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Verification queue'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: 'Doctors'), Tab(text: 'Chemists')],
          ),
        ),
        body: TabBarView(
          children: [
            _PendingDoctorsList(),
            _PendingChemistsList(),
          ],
        ),
      ),
    );
  }
}

class _PendingDoctorsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingDoctorsProvider);
    return pending.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(message: 'No doctors awaiting verification.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final d = list[i];
            return Card(
              child: ListTile(
                title: Text(d.name.isEmpty ? d.userId : d.name),
                subtitle: Text(
                  'License: ${d.licenseNumber ?? '—'} · ${d.specialties.join(', ')}\n'
                  '${d.verificationDocuments.length} document(s) uploaded',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(profileRepositoryProvider)
                        .adminSetDoctorVerified(d.userId, true);
                    ref.invalidate(_pendingDoctorsProvider);
                  },
                  child: const Text('Approve'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PendingChemistsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingChemistsProvider);
    return pending.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(message: 'No chemists awaiting verification.');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            return Card(
              child: ListTile(
                title: Text(c.businessName.isEmpty ? c.userId : c.businessName),
                subtitle: Text(
                  'Registration: ${c.registrationNumber ?? '—'}\n'
                  '${c.verificationDocuments.length} document(s) uploaded',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(profileRepositoryProvider)
                        .adminSetChemistVerified(c.userId, true);
                    ref.invalidate(_pendingChemistsProvider);
                  },
                  child: const Text('Approve'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
