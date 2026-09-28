import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/greeting_header.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/models/prescription.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../patient/screens/doctor_profile_screen.dart'
    show publicDoctorProvider;
import '../../patient/widgets/medicine_image.dart';
import '../../prescription/digital_prescription.dart';
import '../../../core/widgets/motion.dart';

/// Live orders for the signed-in chemist (newest first).
final chemistOrdersProvider = StreamProvider.autoDispose<List<model.Order>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(orderRepositoryProvider).watchForChemist(userId);
});

/// Orders waiting for the chemist to act on (shown as a badge on the tab).
final chemistNewOrderCountProvider = Provider.autoDispose<int>(
  (ref) =>
      ref
          .watch(chemistOrdersProvider)
          .valueOrNull
          ?.where((o) => o.status == OrderStatus.placed)
          .length ??
      0,
);

final _prescriptionProvider = FutureProvider.autoDispose
    .family<Prescription?, String>(
      (ref, id) => ref.watch(prescriptionRepositoryProvider).fetchById(id),
    );

/// Which column of the order board.
enum OrderLane { fresh, preparing, ready, done }

OrderLane laneOf(OrderStatus s) => switch (s) {
  OrderStatus.placed => OrderLane.fresh,
  OrderStatus.confirmed => OrderLane.preparing,
  OrderStatus.ready => OrderLane.ready,
  _ => OrderLane.done,
};

/// How long an order has been waiting, and whether that's getting late:
/// amber after 10 minutes, red after 20 (only while it still needs work).
({String label, Color color}) orderAge(
  DateTime createdAt,
  OrderStatus status, {
  DateTime? now,
}) {
  final mins = (now ?? DateTime.now()).difference(createdAt).inMinutes;
  final label = mins < 1
      ? 'just now'
      : mins < 60
      ? '$mins min'
      : mins < 60 * 24
      ? '${mins ~/ 60} h ${mins % 60} min'
      : '${mins ~/ (60 * 24)} d';
  final active =
      status == OrderStatus.placed || status == OrderStatus.confirmed;
  final color = !active
      ? AppColors.inkSoft
      : mins >= 20
      ? AppColors.danger
      : mins >= 10
      ? AppColors.warning
      : AppColors.success;
  return (label: label, color: color);
}

/// The chemist's order board, like a kitchen display: New / Preparing /
/// Ready / Done, each ticket with how long it has been waiting. Swipe a
/// ticket right to move it on (accept, then mark ready).
class ChemistOrdersScreen extends ConsumerStatefulWidget {
  const ChemistOrdersScreen({super.key});

  @override
  ConsumerState<ChemistOrdersScreen> createState() =>
      _ChemistOrdersScreenState();
}

class _ChemistOrdersScreenState extends ConsumerState<ChemistOrdersScreen> {
  OrderLane? _lane;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(chemistOrdersProvider);
    ref.watch(clockTickProvider); // keeps the waiting times current

    final pharmacy = ref.watch(currentChemistProfileProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: ordersAsync.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: friendlyError(e)),
          data: (orders) {
            final byLane = {
              for (final l in OrderLane.values)
                l: [
                  for (final o in orders)
                    if (laneOf(o.status) == l) o,
                ],
            };
            // Oldest first where work is waiting, so the longest wait is on top.
            for (final l in [OrderLane.fresh, OrderLane.preparing]) {
              byLane[l]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            }
            final lane =
                _lane ??
                (byLane[OrderLane.fresh]!.isNotEmpty
                    ? OrderLane.fresh
                    : byLane[OrderLane.preparing]!.isNotEmpty
                    ? OrderLane.preparing
                    : OrderLane.fresh);
            final list = byLane[lane]!;

            final waiting = byLane[OrderLane.fresh]!.length;
            final preparing = byLane[OrderLane.preparing]!.length;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: FadeSlideIn(
                    child: GreetingHeader(
                      name: (pharmacy?.businessName ?? '').trim().isEmpty
                          ? 'Welcome'
                          : pharmacy!.businessName,
                      subtitle: waiting > 0
                          ? '$waiting new ${waiting == 1 ? 'order is' : 'orders are'} waiting for you.'
                          : preparing > 0
                          ? '$preparing ${preparing == 1 ? 'order' : 'orders'} being prepared.'
                          : 'All caught up. New orders appear here straight away.',
                      avatarPath: ref
                          .watch(currentAppUserProvider)
                          .valueOrNull
                          ?.avatarUrl,
                      onAvatarTap: () => context.go('/chemist/account'),
                      actions: [
                        NotificationBell(
                          count: ref.watch(unreadNotificationCountProvider),
                          onPressed: () =>
                              context.push('/chemist/notifications'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    children: [
                      for (final l in OrderLane.values) ...[
                        ChoiceChip(
                          label: Text(
                            '${_laneLabel(l)}'
                            '${l == OrderLane.done || byLane[l]!.isEmpty ? '' : '  ${byLane[l]!.length}'}',
                          ),
                          selected: lane == l,
                          onSelected: (_) => setState(() => _lane = l),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: orders.isEmpty
                      ? const EmptyView(
                          message:
                              'No orders yet.\nWhen a patient orders from you, it appears here straight away.',
                          icon: LucideIcons.receipt,
                        )
                      : list.isEmpty
                      ? EmptyView(
                          message: switch (lane) {
                            OrderLane.fresh => 'No new orders right now.',
                            OrderLane.preparing => 'Nothing being prepared.',
                            OrderLane.ready => 'No orders waiting for pickup.',
                            OrderLane.done => 'No finished orders yet.',
                          },
                          icon: LucideIcons.inbox,
                        )
                      : LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth >= 1100
                                ? 3
                                : c.maxWidth >= 700
                                ? 2
                                : 1;
                            if (cols == 1) {
                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  16,
                                ),
                                itemCount: list.length,
                                itemBuilder: (context, i) => FadeSlideIn(
                                  key: ValueKey(list[i].id),
                                  index: i,
                                  child: _OrderTicket(order: list[i]),
                                ),
                              );
                            }
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                              child: Wrap(
                                spacing: 12,
                                children: [
                                  for (final o in list)
                                    SizedBox(
                                      width:
                                          (c.maxWidth - 32 - 12 * (cols - 1)) /
                                          cols,
                                      child: _OrderTicket(order: o),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _laneLabel(OrderLane l) => switch (l) {
    OrderLane.fresh => 'New',
    OrderLane.preparing => 'Preparing',
    OrderLane.ready => 'Ready',
    OrderLane.done => 'Done',
  };
}

class _OrderTicket extends ConsumerWidget {
  const _OrderTicket({required this.order});

  final model.Order order;

  (String, Color, Color) get _status => switch (order.status) {
    OrderStatus.placed => ('New', AppColors.primary, AppColors.primarySoft),
    OrderStatus.confirmed => (
      'Preparing',
      AppColors.warning,
      AppColors.warningSoft,
    ),
    OrderStatus.ready => ('Ready', AppColors.success, AppColors.successSoft),
    OrderStatus.fulfilled => ('Collected', AppColors.inkSoft, AppColors.border),
    OrderStatus.disputed => (
      'Disputed',
      AppColors.danger,
      AppColors.dangerSoft,
    ),
    OrderStatus.refunded => ('Refunded', AppColors.inkSoft, AppColors.border),
  };

  /// The next step for this ticket, if any: (label, icon, action).
  (String, IconData, Future<void> Function())? _next(WidgetRef ref) {
    final repo = ref.read(orderRepositoryProvider);
    return switch (order.status) {
      OrderStatus.placed => (
        'Accept and prepare',
        LucideIcons.check,
        () => repo.chemistConfirm(order.id),
      ),
      OrderStatus.confirmed => (
        'Mark ready',
        LucideIcons.packageCheck,
        () => repo.chemistMarkReady(order.id),
      ),
      _ => null,
    };
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final (label, fg, bg) = _status;
    final code = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
    final age = orderAge(order.createdAt.toLocal(), order.status);
    final next = _next(ref);
    final delivery = order.fulfillmentType == FulfillmentType.delivery;

    final ticket = Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: age.color == AppColors.danger
              ? AppColors.danger
              : AppColors.border,
          width: age.color == AppColors.danger ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${code.toUpperCase()}',
                    style: theme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Icon(LucideIcons.timer, size: 16, color: age.color),
                const SizedBox(width: 4),
                Text(
                  age.label,
                  style: theme.titleSmall?.copyWith(color: age.color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(text: label, fg: fg, bg: bg),
                _Tag(
                  text: delivery ? 'Delivery' : 'Pickup',
                  icon: delivery ? LucideIcons.bike : LucideIcons.store,
                  fg: AppColors.ink,
                  bg: AppColors.primarySofter,
                ),
                if (order.prescriptionId != null)
                  _Tag(
                    text: 'Rx',
                    icon: LucideIcons.fileText,
                    fg: AppColors.warning,
                    bg: AppColors.warningSoft,
                  ),
              ],
            ),
            const Divider(height: 22),
            for (final i in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${i.quantity}×',
                        style: theme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (i.drug != null)
                      MedicineImage(drug: i.drug!, size: 34, radius: 8)
                    else
                      const Icon(LucideIcons.pill, color: AppColors.inkFaint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        i.drugName ?? 'Item',
                        style: theme.bodyLarge?.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatDateTime(order.createdAt.toLocal()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall,
                  ),
                ),
                Text('Paid ', style: theme.bodySmall),
                Text(formatKes(order.totalAmount), style: theme.titleSmall),
              ],
            ),
            if (order.prescriptionId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () =>
                    _showPrescription(context, order.prescriptionId!),
                icon: const Icon(LucideIcons.fileText, size: 16),
                label: const Text('Check the prescription'),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () => _run(context, next.$3),
                icon: Icon(next.$2, size: 18),
                label: Text(next.$1),
              ),
            ] else if (order.status == OrderStatus.ready) ...[
              const SizedBox(height: 8),
              Text(
                'Waiting for the patient to confirm they received it.',
                style: theme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );

    if (next == null) return ticket;
    return Dismissible(
      key: ValueKey('ticket-${order.id}-${order.status.name}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        await _run(context, next.$3);
        // The live list moves the ticket to its next lane.
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.success,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(next.$2, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              next.$1,
              style: theme.titleSmall?.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
      child: ticket,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.text,
    required this.fg,
    required this.bg,
    this.icon,
  });

  final String text;
  final Color fg;
  final Color bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showPrescription(BuildContext context, String prescriptionId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PrescriptionSheet(prescriptionId: prescriptionId),
  );
}

class _PrescriptionSheet extends ConsumerWidget {
  const _PrescriptionSheet({required this.prescriptionId});

  final String prescriptionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_prescriptionProvider(prescriptionId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: async.when(
        loading: () => const SizedBox(height: 200, child: LoadingView()),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (p) {
          if (p == null) {
            return const ErrorView(message: 'Prescription not found');
          }
          if (p.source == PrescriptionSource.externalUpload) {
            final url = p.imageUrl == null
                ? null
                : ref
                      .read(prescriptionRepositoryProvider)
                      .publicUrlForUpload(p.imageUrl!);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Uploaded prescription photo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (url != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
              ],
            );
          }
          final doctor = p.doctorId == null
              ? null
              : ref.watch(publicDoctorProvider(p.doctorId!)).valueOrNull;
          return SingleChildScrollView(
            child: DigitalPrescription(
              doctorName: doctor?.name ?? 'GoDoctor doctor',
              doctorDetail: doctor?.primarySpecialty,
              patientName: 'GoDoctor patient',
              items: p.items,
              issuedAt: p.issuedAt.toLocal(),
              validUntil: p.validUntil,
              reference: p.id,
            ),
          );
        },
      ),
    );
  }
}
