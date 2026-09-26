import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _patientOrdersProvider = FutureProvider<List<model.Order>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(orderRepositoryProvider).fetchForPatient(userId);
});

const _statusSteps = ['placed', 'confirmed', 'ready', 'fulfilled'];

const Map<String, IconData> _statusIcons = {
  'placed': LucideIcons.receipt,
  'confirmed': LucideIcons.circleCheck,
  'ready': LucideIcons.package,
  'fulfilled': LucideIcons.badgeCheck,
};

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(_patientOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Order status')),
      body: SafeArea(
        child: ordersAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: '$e'),
          data: (orders) {
            final order = orders.where((o) => o.id == orderId).firstOrNull;
            if (order == null) {
              return const ErrorView(message: 'Order not found');
            }
            return _OrderDetail(order: order, ref: ref);
          },
        ),
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.order, required this.ref});

  final model.Order order;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isDisputed = order.status.name == 'disputed';
    final currentIndex = isDisputed
        ? -1
        : _statusSteps.indexOf(order.status.name);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const InstallPromptBanner(),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(
                          LucideIcons.store,
                          size: 20,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      order.chemistName ?? 'Chemist',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...order.items.map(
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.pill,
                          size: 14,
                          color: AppColors.inkFaint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${i.drugName ?? 'Item'} x${i.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          'KES ${i.unitPrice.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'KES ${order.totalAmount.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      order.escrowStatus.name == 'held'
                          ? LucideIcons.lockKeyhole
                          : LucideIcons.lockKeyholeOpen,
                      size: 14,
                      color: AppColors.inkFaint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Escrow: ${order.escrowStatus.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isDisputed)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(LucideIcons.flag, color: AppColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text('This order has been flagged for manual review.'),
                ),
              ],
            ),
          )
        else
          _OrderStepper(currentIndex: currentIndex),
        const SizedBox(height: 20),
        if (order.status.name == 'ready')
          FilledButton.icon(
            icon: const Icon(LucideIcons.circleCheckBig, size: 18),
            label: const Text('Confirm receipt & release payment'),
            onPressed: () async {
              await ref
                  .read(orderRepositoryProvider)
                  .patientConfirmReceipt(order.id);
              ref.invalidate(_patientOrdersProvider);
            },
          ),
        const SizedBox(height: 10),
        if (order.status.name != 'fulfilled' && order.status.name != 'disputed')
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.flag, size: 18),
            label: const Text('Report a problem'),
            onPressed: () async {
              await ref.read(orderRepositoryProvider).flagDisputed(order.id);
              ref.invalidate(_patientOrdersProvider);
            },
          ),
      ],
    );
  }
}

class _OrderStepper extends StatelessWidget {
  const _OrderStepper({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: List.generate(_statusSteps.length, (i) {
            final step = _statusSteps[i];
            final isDone = i <= currentIndex;
            final isCurrent =
                i == currentIndex.clamp(0, _statusSteps.length - 1);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDone
                            ? AppColors.primary
                            : AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _statusIcons[step]!,
                          size: 16,
                          color: isDone ? Colors.white : AppColors.inkFaint,
                        ),
                      ),
                    ),
                    if (i != _statusSteps.length - 1)
                      Container(
                        width: 2,
                        height: 32,
                        color: isDone && i < currentIndex
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    _label(step),
                    style: isCurrent
                        ? Theme.of(context).textTheme.titleSmall
                        : Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDone ? AppColors.ink : AppColors.inkFaint,
                          ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _label(String s) => switch (s) {
    'placed' => 'Order placed',
    'confirmed' => 'Confirmed by chemist',
    'ready' => 'Ready for pickup/delivery',
    'fulfilled' => 'Fulfilled',
    _ => s,
  };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
