import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/install_prompt_banner.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';

/// One order, updated live as the pharmacy confirms and prepares it.
final orderLiveProvider = StreamProvider.autoDispose
    .family<model.Order?, String>((ref, id) {
      // Pull to refresh re-reads it too.
      ref.watch(liveTick(LiveTable.orders));
      return ref.watch(orderRepositoryProvider).watchOrder(id);
    });

const _steps = [
  OrderStatus.placed,
  OrderStatus.confirmed,
  OrderStatus.ready,
  OrderStatus.fulfilled,
];

class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderLiveProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order status')),
      body: SafeArea(
        child: orderAsync.when(
          skipLoadingOnRefresh: true,
          skipLoadingOnReload: true,
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: friendlyError(e)),
          data: (order) => order == null
              ? const ErrorView(message: 'Order not found')
              : LiveRefresh(child: _OrderDetail(order: order)),
        ),
      ),
    );
  }
}

class _OrderDetail extends ConsumerWidget {
  const _OrderDetail({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order.status;
    final open =
        status == OrderStatus.placed ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.ready;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const InstallPromptBanner(),
        _StatusHero(order: order),
        const SizedBox(height: 16),
        if (status == OrderStatus.disputed || status == OrderStatus.refunded)
          _ProblemCard(order: order)
        else
          _Timeline(order: order),
        const SizedBox(height: 16),
        _ItemsCard(order: order),
        const SizedBox(height: 20),
        if (status == OrderStatus.ready)
          FilledButton.icon(
            icon: const Icon(LucideIcons.circleCheckBig, size: 18),
            label: const Text('I\'ve got my medicine'),
            onPressed: () => _confirmReceipt(context, ref),
          )
        else if (status == OrderStatus.confirmed)
          OutlinedButton.icon(
            icon: const Icon(LucideIcons.circleCheckBig, size: 18),
            label: const Text('Already collected it? Confirm'),
            onPressed: () => _confirmReceipt(context, ref),
          ),
        if (open) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(LucideIcons.flag, size: 16),
            label: const Text('Report a problem'),
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            onPressed: () => _reportProblem(context, ref),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmReceipt(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Got your medicine?'),
        content: Text(
          'We\'ll release KES ${order.totalAmount.toStringAsFixed(0)} to '
          '${order.chemistName ?? 'the pharmacy'}. Only confirm once you have '
          'everything you ordered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, I have it'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref.read(orderRepositoryProvider).patientConfirmReceipt(order.id),
      done: 'Thanks! Payment released to the pharmacy.',
    );
  }

  Future<void> _reportProblem(BuildContext context, WidgetRef ref) async {
    final note = await showDialog<String>(
      context: context,
      builder: (_) => const _ProblemDialog(),
    );
    if (note == null || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(orderRepositoryProvider)
          .flagDisputed(order.id, note: note.isEmpty ? null : note),
      done: 'Reported. Our team will follow up — your payment stays held.',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action, {
    required String done,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(orderLiveProvider(order.id));
      refreshAllLive(ref);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// The headline: where the order is right now, in plain words.
class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final delivery = order.fulfillmentType == FulfillmentType.delivery;
    final (icon, title, body, color, soft) = switch (order.status) {
      OrderStatus.placed => (
        LucideIcons.receipt,
        'Waiting for the pharmacy',
        '${order.chemistName ?? 'The pharmacy'} will confirm your order shortly.',
        AppColors.primary,
        AppColors.primarySoft,
      ),
      OrderStatus.confirmed => (
        LucideIcons.pillBottle,
        'Being prepared',
        'The pharmacist is getting your medicine ready.',
        AppColors.primary,
        AppColors.primarySoft,
      ),
      OrderStatus.ready => (
        delivery ? LucideIcons.truck : LucideIcons.package,
        delivery ? 'On its way' : 'Ready for pickup',
        delivery
            ? 'Your medicine is on its way to you.'
            : 'Collect it at ${order.chemistName ?? 'the pharmacy'}.',
        AppColors.accentTeal,
        AppColors.accentTealSoft,
      ),
      OrderStatus.fulfilled => (
        LucideIcons.badgeCheck,
        'Completed',
        'Payment released to ${order.chemistName ?? 'the pharmacy'}.',
        AppColors.success,
        AppColors.successSoft,
      ),
      OrderStatus.disputed => (
        LucideIcons.flag,
        'Problem reported',
        'Our team is looking into it. Your payment stays held.',
        AppColors.warning,
        AppColors.warningSoft,
      ),
      OrderStatus.refunded => (
        LucideIcons.undo2,
        'Refunded',
        'Your payment has been returned.',
        AppColors.inkSoft,
        AppColors.border,
      ),
    };
    final live =
        order.status == OrderStatus.placed ||
        order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.ready;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(order.status),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
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
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (live) ...[
                      const SizedBox(width: 8),
                      PulseDot(color: color, size: 8),
                      const SizedBox(width: 4),
                      Text(
                        'Live',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: color),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(order.status);
    final delivery = order.fulfillmentType == FulfillmentType.delivery;
    final times = [
      order.createdAt,
      order.confirmedAt,
      order.readyAt,
      order.fulfilledAt,
    ];
    final labels = [
      'Order placed & paid',
      'Confirmed by the pharmacy',
      delivery ? 'Out for delivery' : 'Ready for pickup',
      'Received — payment released',
    ];
    final fmt = DateFormat('d MMM, h:mm a');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          children: [
            for (var i = 0; i < _steps.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: i <= current
                              ? AppColors.primary
                              : AppColors.primarySoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          i < current || order.status == OrderStatus.fulfilled
                              ? LucideIcons.check
                              : _icons[i],
                          size: 15,
                          color: i <= current
                              ? Colors.white
                              : AppColors.inkFaint,
                        ),
                      ),
                      if (i != _steps.length - 1)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          width: 2,
                          height: 28,
                          color: i < current
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              labels[i],
                              style: i == current
                                  ? Theme.of(context).textTheme.titleSmall
                                  : Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.copyWith(
                                      color: i < current
                                          ? AppColors.ink
                                          : AppColors.inkFaint,
                                    ),
                            ),
                          ),
                          if (i <= current && times[i] != null)
                            Text(
                              fmt.format(times[i]!.toLocal()),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.inkFaint),
                            ),
                        ],
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

  static const _icons = [
    LucideIcons.receipt,
    LucideIcons.store,
    LucideIcons.package,
    LucideIcons.badgeCheck,
  ];
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final refunded = order.status == OrderStatus.refunded;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: refunded ? AppColors.primarySofter : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            refunded
                ? 'This order was refunded and the medicine returned to stock.'
                : 'We\'ve flagged this order for our team. They\'ll contact '
                      'you and the pharmacy to sort it out.',
          ),
          if (order.problemNote != null) ...[
            const SizedBox(height: 10),
            Text(
              'You said: "${order.problemNote}"',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final held = order.escrowStatus == EscrowStatus.held;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.push('/patient/chemist/${order.chemistId}'),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.store,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.chemistName ?? 'Pharmacy',
                          style: text.titleSmall,
                        ),
                        Text(
                          order.fulfillmentType == FulfillmentType.delivery
                              ? 'Delivery · Order #${_short(order.id)}'
                              : 'Pickup · Order #${_short(order.id)}',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.inkFaint,
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            for (final i in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                        '${i.drugName ?? 'Medicine'} × ${i.quantity}',
                        style: text.bodyMedium,
                      ),
                    ),
                    Text(
                      'KES ${(i.unitPrice * i.quantity).toStringAsFixed(0)}',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total paid', style: text.titleSmall),
                Text(
                  'KES ${order.totalAmount.toStringAsFixed(0)}',
                  style: text.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  held ? LucideIcons.shieldCheck : LucideIcons.lockKeyholeOpen,
                  size: 14,
                  color: held ? AppColors.success : AppColors.inkFaint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(switch (order.escrowStatus) {
                    EscrowStatus.held =>
                      'Held safely until you confirm you have it',
                    EscrowStatus.released => 'Released to the pharmacy',
                    EscrowStatus.refunded => 'Refunded to you',
                  }, style: text.bodySmall?.copyWith(color: AppColors.inkSoft)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String id) =>
      (id.length > 8 ? id.substring(0, 8) : id).toUpperCase();
}

class _ProblemDialog extends StatefulWidget {
  const _ProblemDialog();

  @override
  State<_ProblemDialog> createState() => _ProblemDialogState();
}

class _ProblemDialogState extends State<_ProblemDialog> {
  final _note = TextEditingController();
  String? _reason;

  static const _reasons = [
    'Wrong or missing medicine',
    'Pharmacy says it\'s out of stock',
    'Taking too long',
    'Something else',
  ];

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What went wrong?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _reasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(
                hintText: 'Tell us a little more (optional)',
              ),
            ),
            Text(
              'Your payment stays held while we sort it out.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _reason == null
              ? null
              : () {
                  final extra = _note.text.trim();
                  Navigator.pop(
                    context,
                    extra.isEmpty ? _reason! : '${_reason!}: $extra',
                  );
                },
          child: const Text('Report'),
        ),
      ],
    );
  }
}
