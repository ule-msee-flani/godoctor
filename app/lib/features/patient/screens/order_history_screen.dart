import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/order.dart' as model;
import '../../../core/widgets/skeleton.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';

final _ordersProvider = FutureProvider<List<model.Order>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(orderRepositoryProvider).fetchForPatient(userId);
});

const Map<String, ({Color bg, Color fg})> _statusColors = {
  'placed': (bg: AppColors.primarySoft, fg: AppColors.primary),
  'confirmed': (bg: AppColors.primarySoft, fg: AppColors.primary),
  'ready': (bg: AppColors.successSoft, fg: AppColors.success),
  'fulfilled': (bg: AppColors.successSoft, fg: AppColors.success),
  'disputed': (bg: AppColors.dangerSoft, fg: AppColors.danger),
  'refunded': (bg: AppColors.warningSoft, fg: AppColors.warning),
};

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Order history')),
    body: const OrderHistoryList(),
  );
}

/// The list itself, reused by the Activity tab.
class OrderHistoryList extends ConsumerWidget {
  const OrderHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(_ordersProvider);
    return orders.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorView(message: '$e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyView(
            message: 'No orders yet.',
            icon: LucideIcons.receipt,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final order = list[i];
            final colors =
                _statusColors[order.status.name] ??
                (bg: AppColors.primarySoft, fg: AppColors.primary);
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => context.push('/patient/order/${order.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.store,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.chemistName ?? 'Chemist',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'KES ${order.totalAmount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.name,
                          style: TextStyle(
                            color: colors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
