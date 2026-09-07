import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/repository_providers.dart';

final _consultationStreamProvider = StreamProvider.family<Consultation?, String>(
  (ref, id) => ref.watch(consultationRepositoryProvider).watchConsultation(id),
);

class ConsultationWaitingScreen extends ConsumerWidget {
  const ConsultationWaitingScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationAsync = ref.watch(
      _consultationStreamProvider(consultationId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your consultation')),
      body: SafeArea(
        child: consultationAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: 'Something went wrong: $e'),
          data: (consultation) {
            if (consultation == null) {
              return const ErrorView(message: 'Consultation not found');
            }
            return switch (consultation.status) {
              ConsultationStatus.requested => const _WaitingBody(),
              ConsultationStatus.matched ||
              ConsultationStatus.inProgress => _MatchedBody(
                consultation: consultation,
              ),
              ConsultationStatus.unmatched => const _UnmatchedBody(),
              ConsultationStatus.completed => _CompletedBody(
                consultation: consultation,
              ),
              ConsultationStatus.cancelled => const _CancelledBody(),
            };
          },
        ),
      ),
    );
  }
}

class _WaitingBody extends StatelessWidget {
  const _WaitingBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Looking for an available doctor...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This usually takes less than a minute.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchedBody extends StatelessWidget {
  const _MatchedBody({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 16),
            Text(
              'You\'re matched with a doctor!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.videocam),
              label: const Text('Join the call'),
              onPressed: () =>
                  context.push('/patient/call/${consultation.id}'),
            ),
            const SizedBox(height: 20),
            const InstallPromptBanner(),
          ],
        ),
      ),
    );
  }
}

class _CompletedBody extends StatelessWidget {
  const _CompletedBody({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, color: Colors.green, size: 56),
            const SizedBox(height: 16),
            Text(
              'Consultation completed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const Text('View prescription'),
              onPressed: () => context.push('/patient/prescriptions'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go('/patient'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnmatchedBody extends StatelessWidget {
  const _UnmatchedBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_disabled, size: 56, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'No doctors are available right now',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Please try again shortly, or check back later.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/patient'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelledBody extends StatelessWidget {
  const _CancelledBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_outlined, size: 56),
            const SizedBox(height: 16),
            const Text('This consultation was cancelled.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/patient'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
