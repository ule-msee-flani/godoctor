import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/loading_view.dart';
import '../widgets/review_sheet.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/repository_providers.dart';

final _consultationStreamProvider =
    StreamProvider.family<Consultation?, String>(
      (ref, id) =>
          ref.watch(consultationRepositoryProvider).watchConsultation(id),
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
              ConsultationStatus.matched || ConsultationStatus.inProgress =>
                _MatchedBody(consultation: consultation),
              ConsultationStatus.unmatched => const _UnmatchedBody(),
              ConsultationStatus.completed => _CompletedBody(
                consultation: consultation,
              ),
              ConsultationStatus.cancelled => const _CancelledBody(),
              ConsultationStatus.scheduled => _ScheduledBody(
                consultation: consultation,
              ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppImage(
              assetPath: 'assets/images/waiting_search.png',
              height: 200,
              width: 280,
              borderRadius: 28,
              placeholderIcon: LucideIcons.search,
              placeholderLabel: 'assets/images/waiting_search.png',
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.circleCheckBig,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'You\'re matched with a doctor!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'They\'re ready to see you whenever you are.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(LucideIcons.video, size: 18),
              label: const Text('Join the call'),
              onPressed: () => context.push('/patient/call/${consultation.id}'),
            ),
            const SizedBox(height: 20),
            const InstallPromptBanner(),
          ],
        ),
      ),
    );
  }
}

class _CompletedBody extends ConsumerWidget {
  const _CompletedBody({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorName = consultation.doctorId == null
        ? null
        : ref
              .watch(publicDoctorProvider(consultation.doctorId!))
              .valueOrNull
              ?.name;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.badgeCheck,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Consultation completed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(LucideIcons.fileText, size: 18),
              label: const Text('View prescription'),
              onPressed: () => context.push('/patient/prescriptions'),
            ),
            const SizedBox(height: 10),
            ReviewPrompt(
              consultationId: consultation.id,
              doctorName: doctorName ?? 'your doctor',
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.hourglass,
                  color: AppColors.warning,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No doctors are available right now',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Please try again shortly, or check back later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.circleX,
                  color: AppColors.inkSoft,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'This consultation was cancelled.',
              style: Theme.of(context).textTheme.titleMedium,
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

/// A booked appointment reached via the on-demand waiting route (e.g. from an
/// older link): send the patient to the proper appointment page.
class _ScheduledBody extends StatelessWidget {
  const _ScheduledBody({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.calendarCheck,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'This is a booked appointment',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.pushReplacement(
                '/patient/appointment/${consultation.id}',
              ),
              child: const Text('View appointment'),
            ),
          ],
        ),
      ),
    );
  }
}
