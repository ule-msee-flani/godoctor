import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

const _statusSteps = [
  'placed',
  'confirmed',
  'ready',
  'fulfilled',
];

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
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.chemistName ?? 'Chemist', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...order.items.map(
                  (i) => Text('${i.drugName ?? 'Item'} x${i.quantity} — KES ${i.unitPrice.toStringAsFixed(0)}'),
                ),
                const Divider(height: 20),
                Text(
                  'Total: KES ${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('Escrow: ${order.escrowStatus.name}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isDisputed)
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('This order has been flagged for manual review.'),
            ),
          )
        else
          Stepper(
            currentStep: currentIndex.clamp(0, _statusSteps.length - 1),
            controlsBuilder: (context, details) => const SizedBox.shrink(),
            steps: _statusSteps
                .map((s) => Step(title: Text(_label(s)), content: const SizedBox.shrink()))
                .toList(),
          ),
        const SizedBox(height: 12),
        if (order.status.name == 'ready')
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Confirm receipt & release payment'),
            onPressed: () async {
              await ref.read(orderRepositoryProvider).patientConfirmReceipt(order.id);
              ref.invalidate(_patientOrdersProvider);
            },
          ),
        const SizedBox(height: 8),
        if (order.status.name != 'fulfilled' && order.status.name != 'disputed')
          OutlinedButton.icon(
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Report a problem'),
            onPressed: () async {
              await ref.read(orderRepositoryProvider).flagDisputed(order.id);
              ref.invalidate(_patientOrdersProvider);
            },
          ),
      ],
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
