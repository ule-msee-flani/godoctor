import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _ordersProvider = FutureProvider((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(orderRepositoryProvider).fetchForPatient(userId);
});

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(_ordersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Order history')),
      body: orders.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: '$e'),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyView(message: 'No orders yet.', icon: Icons.receipt_long);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final order = list[i];
              return Card(
                child: ListTile(
                  title: Text(order.chemistName ?? 'Chemist'),
                  subtitle: Text('KES ${order.totalAmount.toStringAsFixed(0)} · ${order.status.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/patient/order/${order.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
