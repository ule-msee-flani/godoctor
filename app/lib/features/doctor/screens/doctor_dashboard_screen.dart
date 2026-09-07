import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/doctor_profile.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _offersStreamProvider = StreamProvider.family<List<ConsultationOffer>, String>(
  (ref, doctorId) =>
      ref.watch(consultationRepositoryProvider).watchOffersForDoctor(doctorId),
);

class DoctorDashboardScreen extends ConsumerWidget {
  const DoctorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentDoctorProfileProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Consultation history',
            onPressed: () => context.push('/doctor/history'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: '$e'),
          data: (profile) {
            if (profile == null || userId == null) {
              return const ErrorView(message: 'Profile not found');
            }
            return _DashboardBody(profile: profile, doctorId: userId);
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.profile, required this.doctorId});

  final DoctorProfile profile;
  final String doctorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(_offersStreamProvider(doctorId));
    final isAvailable = profile.status == DoctorStatus.available;
    final isBusy = profile.status == DoctorStatus.busy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  isAvailable ? Icons.wifi : Icons.wifi_off,
                  color: isAvailable ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isBusy
                        ? 'In a consultation'
                        : (isAvailable ? 'Available for consultations' : 'Offline'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Switch(
                  value: isAvailable,
                  onChanged: isBusy
                      ? null
                      : (value) async {
                          await ref
                              .read(profileRepositoryProvider)
                              .setDoctorAvailability(value);
                          ref.invalidate(currentDoctorProfileProvider);
                        },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: profile.specialties.map((s) => Chip(label: Text(s))).toList(),
        ),
        const SizedBox(height: 20),
        Text('Incoming offers', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        offersAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('$e'),
          data: (offers) {
            if (offers.isEmpty) {
              return const EmptyView(
                message: 'No pending offers right now.',
                icon: LucideIcons.inbox,
              );
            }
            return Column(
              children: offers
                  .map((o) => _OfferCard(offer: o))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.offer});

  final ConsultationOffer offer;

  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final remaining = widget.offer.expiresAt.difference(DateTime.now());
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _respond(bool accept) async {
    _timer?.cancel();
    await ref
        .read(consultationRepositoryProvider)
        .respondToOffer(offerId: widget.offer.id, accept: accept);
    if (accept && mounted) {
      context.push('/doctor/call/${widget.offer.consultationId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active),
                const SizedBox(width: 8),
                const Expanded(child: Text('New consultation request')),
                Text(
                  '${_remaining.inSeconds}s',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respond(false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _respond(true),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
