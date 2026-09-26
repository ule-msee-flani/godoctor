import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/support.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../support/support_screen.dart' show TicketTile;

final _pendingDoctorsProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).fetchPendingDoctors(),
);
final _pendingChemistsProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).fetchPendingChemists(),
);
final _allTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>(
  (ref) => ref.watch(supportRepositoryProvider).allTickets(),
);
final _ratingSummaryProvider =
    FutureProvider.autoDispose<({double average, int count})>(
      (ref) => ref.watch(supportRepositoryProvider).ratingSummary(),
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
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Doctors'),
              Tab(text: 'Chemists'),
              Tab(text: 'Support'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PendingDoctorsList(),
            _PendingChemistsList(),
            const _SupportInbox(),
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

/// Help requests, complaints, feedback and deletion requests from every
/// user, newest activity first, plus how people rate the app.
class _SupportInbox extends ConsumerWidget {
  const _SupportInbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final tickets = ref.watch(_allTicketsProvider);
    final rating = ref.watch(_ratingSummaryProvider).valueOrNull;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_ratingSummaryProvider);
        ref.invalidate(_allTicketsProvider);
        await ref.read(_allTicketsProvider.future);
      },
      child: tickets.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (list) {
          final open = list.where((t) => t.status == 'open').length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                [
                  '$open waiting for a reply',
                  if (rating != null && rating.count > 0)
                    'app rating ${rating.average.toStringAsFixed(1)} / 5 from ${rating.count}',
                ].join(' · '),
                style: theme.titleSmall,
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyView(message: 'No support messages yet.')
              else
                for (final t in list)
                  TicketTile(ticket: t, route: '/admin/support/${t.id}'),
            ],
          );
        },
      ),
    );
  }
}
