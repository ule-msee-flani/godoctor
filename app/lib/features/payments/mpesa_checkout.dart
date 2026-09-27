import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/utils/local_touch.dart';
import '../../core/widgets/heartbeat_loader.dart';
import '../../core/widgets/motion.dart';
import '../../data/models/billing.dart';
import '../../data/providers/auth_providers.dart';
import '../patient/profile/billing_screen.dart' show paymentMethodsProvider;

/// Test mode: stands in for the M-Pesa prompt on the patient's phone (the
/// Daraja STK push) until payments are connected.
Future<void> simulateMpesaPrompt() =>
    Future<void>.delayed(const Duration(milliseconds: 1400));

/// "Pay with M-Pesa 0712 345 678 · Change": the saved default number, or
/// the phone number on the account.
class MpesaPayWithCard extends ConsumerWidget {
  const MpesaPayWithCard({super.key});

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

/// The bar at the bottom of a checkout: total and the pay button; while
/// paying, "Check your phone" with the heartbeat.
class MpesaPayBar extends StatelessWidget {
  const MpesaPayBar({
    super.key,
    required this.total,
    required this.paying,
    required this.onPay,
    this.enabled = true,
    this.label,
  });

  final double total;
  final bool paying;
  final bool enabled;
  final VoidCallback onPay;

  /// Defaults to "Pay KES X".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: paying
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const HeartbeatLoader(size: 30),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Check your phone',
                                  style: theme.titleSmall,
                                ),
                                Text(
                                  'Enter your M-Pesa PIN to pay '
                                  '${formatKes(total)} to GoDoctor.',
                                  style: theme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: theme.bodySmall),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, a) =>
                          FadeTransition(opacity: a, child: child),
                      child: Text(
                        formatKes(total),
                        key: ValueKey(total),
                        style: theme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: paying || !enabled ? null : onPay,
                    icon: const Icon(LucideIcons.smartphone, size: 18),
                    label: Text(
                      paying
                          ? 'Waiting for M-Pesa…'
                          : label ?? 'Pay ${formatKes(total)}',
                    ),
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

/// Payment went through: a check mark that draws itself and a thank-you.
class PaymentSuccessView extends StatefulWidget {
  const PaymentSuccessView({super.key, required this.message});

  final String message;

  @override
  State<PaymentSuccessView> createState() => _PaymentSuccessViewState();
}

class _PaymentSuccessViewState extends State<PaymentSuccessView> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedCheck(size: 88, haptic: false),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 2,
              child: Text(LocalTouch.thanks, style: theme.headlineSmall),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              index: 3,
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
