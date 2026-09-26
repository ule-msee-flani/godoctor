import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/local_touch.dart';
import '../../../core/widgets/heartbeat_loader.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/billing.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../screens/doctor_profile_screen.dart' show publicDoctorProvider;
import '../family/family_session_panel.dart';
import '../profile/billing_screen.dart' show paymentMethodsProvider;
import '../widgets/doctor_widgets.dart';
import 'consult_flow.dart';

/// "See a doctor", step 3 of 3: pay, then the consultation starts. The doctor
/// is reserved for this patient for 10 minutes while they pay.
///
/// Payment is SIMULATED until M-Pesa (Daraja) is integrated: the button
/// records a successful test payment on the server.
class ConsultPayScreen extends ConsumerStatefulWidget {
  const ConsultPayScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  ConsumerState<ConsultPayScreen> createState() => _ConsultPayScreenState();
}

class _ConsultPayScreenState extends ConsumerState<ConsultPayScreen> {
  bool _paying = false;
  bool _left = false;

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      // Test mode: stands in for the M-Pesa prompt on the patient's phone.
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      await ref
          .read(consultationRepositoryProvider)
          .payForConsultation(widget.consultationId);
      // The live stream flips to in_progress and _goToCall() takes over.
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text('The doctor will be released for other patients.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(consultationRepositoryProvider)
          .cancelRequest(widget.consultationId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) _toast(friendlyError(e));
    }
  }

  /// Once paid: open the consultation (and keep the status page underneath,
  /// so leaving the call lands on "consultation in progress / completed").
  void _goToCall() {
    if (_left) return;
    _left = true;
    ref.read(consultDraftProvider.notifier).state = null;
    HapticFeedback.heavyImpact();
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      context.pushReplacement('/patient/waiting/${widget.consultationId}');
      context.push('/patient/call/${widget.consultationId}');
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appointmentProvider(widget.consultationId));

    return PopScope(
      canPop: !_paying,
      child: Scaffold(
        appBar: AppBar(title: const Text('Pay & see your doctor')),
        body: async.when(
          loading: () => const SkeletonList(itemCount: 3),
          error: (e, _) => ErrorView(message: friendlyError(e)),
          data: (c) {
            if (c == null) return const ErrorView(message: 'Request not found');
            switch (c.status) {
              case ConsultationStatus.awaitingPayment:
                return _PayBody(
                  consultation: c,
                  paying: _paying,
                  onPay: _pay,
                  onCancel: _cancel,
                );
              case ConsultationStatus.matched:
              case ConsultationStatus.inProgress:
              case ConsultationStatus.completed:
                _goToCall();
                return const _PaidMoment();
              default:
                return _EndedBody(onChooseAgain: () => context.pop());
            }
          },
        ),
      ),
    );
  }
}

class _PayBody extends ConsumerWidget {
  const _PayBody({
    required this.consultation,
    required this.paying,
    required this.onPay,
    required this.onCancel,
  });

  final Consultation consultation;
  final bool paying;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final doctor = consultation.doctorId == null
        ? null
        : ref.watch(publicDoctorProvider(consultation.doctorId!)).valueOrNull;
    final fee = consultation.feeAmount ?? 0;
    final free = fee <= 0;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              const ConsultSteps(current: 3),
              const SizedBox(height: 20),
              if (consultation.paymentDueAt != null)
                _ReservationTimer(until: consultation.paymentDueAt!),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      DoctorAvatar(
                        name: doctor?.name ?? 'Doctor',
                        avatarPath: doctor?.avatarPath,
                        radius: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    doctor?.name ?? 'Your doctor',
                                    style: theme.titleSmall,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const VerifiedBadge(),
                              ],
                            ),
                            Text(
                              consultation.specialtyRequested,
                              style: theme.bodySmall,
                            ),
                            if (doctor != null) ...[
                              const SizedBox(height: 4),
                              RatingSummary(doctor: doctor),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('What you told the doctor', style: theme.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        consultation.symptomSummary,
                        style: theme.bodyLarge?.copyWith(color: AppColors.ink),
                      ),
                      const Divider(height: 26),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.video,
                            size: 18,
                            color: AppColors.inkFaint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Video consultation',
                              style: theme.bodyMedium,
                            ),
                          ),
                          Text(
                            free ? 'Free' : formatKes(fee),
                            style: theme.titleMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (!free) ...[const SizedBox(height: 12), const _PayWithCard()],
              const SizedBox(height: 12),
              FamilySessionPanel(consultationId: consultation.id),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.flaskConical,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Test mode: M-Pesa is not connected yet, so no money is taken. '
                        'Tapping Pay records a test payment.',
                        style: theme.bodySmall?.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (paying && !free)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const HeartbeatLoader(size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Check your phone', style: theme.titleSmall),
                              Text(
                                'Enter your M-Pesa PIN to pay ${formatKes(fee)} to GoDoctor.',
                                style: theme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  onPressed: paying ? null : onPay,
                  icon: paying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.smartphone, size: 18),
                  label: Text(
                    paying
                        ? 'Waiting for M-Pesa…'
                        : free
                        ? 'Start consultation'
                        : 'Pay ${formatKes(fee)} with M-Pesa',
                  ),
                ),
                TextButton(
                  onPressed: paying ? null : onCancel,
                  child: const Text('Cancel and choose another doctor'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Dr X is reserved for you · 9:41" -- counts down to the reservation lapse.
class _ReservationTimer extends StatefulWidget {
  const _ReservationTimer({required this.until});

  final DateTime until;

  @override
  State<_ReservationTimer> createState() => _ReservationTimerState();
}

class _ReservationTimerState extends State<_ReservationTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final secs = left.isNegative ? 0 : left.inSeconds;
    final mmss = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
    final urgent = secs < 120;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: urgent ? AppColors.dangerSoft : AppColors.successSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.timer,
            size: 18,
            color: urgent ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your doctor is reserved for you while you pay',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
          Text(
            mmss,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: urgent ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedBody extends StatelessWidget {
  const _EndedBody({required this.onChooseAgain});

  final VoidCallback onChooseAgain;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      message:
          '${LocalTouch.sorry} this request was cancelled or the reservation '
          'expired.\nNo payment was taken.',
      icon: LucideIcons.timerOff,
      action: FilledButton(
        onPressed: onChooseAgain,
        child: const Text('Choose a doctor'),
      ),
    );
  }
}

/// "Pay with M-Pesa 0712 345 678 · Change": the saved default number, or the
/// phone number on the account.
class _PayWithCard extends ConsumerWidget {
  const _PayWithCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final methods =
        ref.watch(paymentMethodsProvider).valueOrNull ??
        const <PaymentMethod>[];
    final mpesa = methods.where((m) => m.isMpesa).toList()
      ..sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    final phone =
        mpesa.firstOrNull?.mpesaPhone ??
        ref.watch(currentAppUserProvider).valueOrNull?.phone;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/patient/profile/billing'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF3BB54A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'M-PESA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pay with', style: theme.bodySmall),
                    Text(
                      phone == null || phone.isEmpty
                          ? 'Add your M-Pesa number'
                          : formatKenyanPhone(phone),
                      style: theme.titleSmall,
                    ),
                  ],
                ),
              ),
              Text(
                'Change',
                style: theme.labelLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Payment went through: a check mark and a thank-you before the call opens.
class _PaidMoment extends StatelessWidget {
  const _PaidMoment();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: AppColors.successSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.check,
                size: 44,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 18),
            Text(LocalTouch.thanks, style: theme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Payment received. Connecting you to your doctor…',
              style: theme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
