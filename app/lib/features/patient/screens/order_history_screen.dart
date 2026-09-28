import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart' as model;
import '../../../core/widgets/skeleton.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';
import '../visits/visit_widgets.dart' show MonthHeader, groupByMonth;

final _ordersProvider = FutureProvider<List<model.Order>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(liveTick(LiveTable.orders));
  if (userId == null) return const [];
  return ref.watch(orderRepositoryProvider).fetchForPatient(userId);
});

/// Label and colours for an order's status, in the patient's words.
(String, Color, Color) orderStatusLook(model.Order o) => switch (o.status) {
  OrderStatus.placed => (
    'Waiting for pharmacy',
    AppColors.primary,
    AppColors.primarySoft,
  ),
  OrderStatus.confirmed => (
    'Being prepared',
    AppColors.primary,
    AppColors.primarySoft,
  ),
  OrderStatus.ready => (
    o.fulfillmentType == FulfillmentType.delivery
        ? 'On its way'
        : 'Ready for pickup',
    AppColors.accentTeal,
    AppColors.accentTealSoft,
  ),
  OrderStatus.fulfilled => (
    'Completed',
    AppColors.success,
    AppColors.successSoft,
  ),
  OrderStatus.disputed => (
    'Problem reported',
    AppColors.warning,
    AppColors.warningSoft,
  ),
  OrderStatus.refunded => ('Refunded', AppColors.inkSoft, AppColors.border),
};

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your orders')),
    body: const OrderHistoryList(),
  );
}

/// The list itself, reused by the Health tab: orders still on their way
/// first, then the rest by month. Updates live.
class OrderHistoryList extends ConsumerWidget {
  const OrderHistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(_ordersProvider);
    return LiveRefresh(
      onRefresh: () => ref.refresh(_ordersProvider.future),
      child: orders.when(
        loading: () => const SkeletonList(),
        error: (e, _) =>
            PullableFill(child: ErrorView(message: friendlyError(e))),
        data: (list) {
          if (list.isEmpty) {
            return PullableFill(
              child: EmptyView(
                message:
                    'No orders yet.\nOrder medicine from pharmacies near you '
                    'and follow it here.',
                icon: LucideIcons.shoppingBag,
                action: FilledButton.icon(
                  icon: const Icon(LucideIcons.pill, size: 18),
                  label: const Text('Order medicine'),
                  onPressed: () => context.push('/patient/medicine-search'),
                ),
              ),
            );
          }
          bool active(model.Order o) =>
              o.status == OrderStatus.placed ||
              o.status == OrderStatus.confirmed ||
              o.status == OrderStatus.ready;
          final current = [
            for (final o in list)
              if (active(o)) o,
          ];
          final past = [
            for (final o in list)
              if (!active(o)) o,
          ];
          var i = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              if (current.isNotEmpty) ...[
                MonthHeader('On the way', count: current.length),
                for (final o in current)
                  FadeSlideIn(
                    index: i++,
                    child: _OrderCard(order: o),
                  ),
              ],
              for (final (label, group) in groupByMonth(
                past,
                (o) => o.createdAt.toLocal(),
              )) ...[
                MonthHeader(label, count: group.length),
                for (final o in group)
                  FadeSlideIn(
                    index: i++,
                    child: _OrderCard(order: o),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (label, fg, bg) = orderStatusLook(order);
    final items = order.items.map((i) => i.drugName ?? 'Medicine').join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/patient/order/${order.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(LucideIcons.shoppingBag, color: fg, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.chemistName ?? 'Pharmacy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      if (items.isNotEmpty)
                        Text(
                          items,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${formatKes(order.totalAmount)} · '
                        '${formatDayShort(order.createdAt.toLocal())}',
                        style: text.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
