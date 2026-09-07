import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _chemistOrdersStreamProvider = StreamProvider.family<List<model.Order>, String>(
  (ref, chemistId) => ref.watch(orderRepositoryProvider).watchForChemist(chemistId),
);

class ChemistOrdersScreen extends ConsumerWidget {
  const ChemistOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const Scaffold(body: LoadingView());

    final ordersAsync = ref.watch(_chemistOrdersStreamProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (orders) {
          if (orders.isEmpty) {
            return const EmptyView(
              message: 'No orders yet.',
              icon: LucideIcons.receipt,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, i) => _OrderRow(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  const _OrderRow({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(orderRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order ${order.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(order.status.name)),
              ],
            ),
            const SizedBox(height: 8),
            ...order.items.map(
              (i) => Text('${i.drugName ?? 'Item'} x${i.quantity}'),
            ),
            const SizedBox(height: 4),
            Text('Total: KES ${order.totalAmount.toStringAsFixed(0)}'),
            Text('Fulfillment: ${order.fulfillmentType.name}'),
            if (order.prescriptionId != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Prescription attached -- verify before preparing.',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (order.status.name == 'placed')
                  FilledButton(
                    onPressed: () => repo.chemistConfirm(order.id),
                    child: const Text('Confirm'),
                  ),
                if (order.status.name == 'confirmed') ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => repo.chemistMarkReady(order.id),
                    child: const Text('Mark ready'),
                  ),
                ],
                if (order.status.name == 'ready') ...[
                  const SizedBox(width: 8),
                  const Text('Waiting for patient pickup/delivery confirmation'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
