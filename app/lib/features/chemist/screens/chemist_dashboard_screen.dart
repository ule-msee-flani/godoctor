import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/greeting_header.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/chemist_dashboard.dart';
import '../../../data/models/public_doctor.dart' show DoctorReview;
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';
import '../../patient/widgets/doctor_widgets.dart' show RatingStars;
import '../../reviews/review_widgets.dart';

/// The pharmacy's numbers, kept live as orders and stock change.
final chemistDashboardProvider = FutureProvider.autoDispose<ChemistDashboard>((
  ref,
) {
  ref.watch(liveTick(LiveTable.orders));
  ref.watch(liveTick(LiveTable.inventory));
  return ref.watch(orderRepositoryProvider).chemistDashboard();
});

/// What patients say about this pharmacy (its own reviews).
final _myReviewsProvider = FutureProvider.autoDispose<List<DoctorReview>>((
  ref,
) {
  ref.watch(liveTick(LiveTable.reviews));
  final me = ref.watch(currentUserIdProvider);
  if (me == null) return const [];
  return ref
      .watch(doctorDirectoryRepositoryProvider)
      .chemistReviews(me, limit: 3);
});

final _myRatingProvider =
    FutureProvider.autoDispose<({double avg, int count})?>((ref) async {
      ref.watch(liveTick(LiveTable.reviews));
      final me = ref.watch(currentUserIdProvider);
      if (me == null) return null;
      final c = await ref
          .watch(doctorDirectoryRepositoryProvider)
          .getChemist(me);
      return c == null ? null : (avg: c.ratingAvg, count: c.ratingCount);
    });

/// The pharmacy's home: what needs doing now, sales, stock health, what to
/// restock, best sellers and what patients say.
class ChemistDashboardScreen extends ConsumerWidget {
  const ChemistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacy = ref.watch(currentChemistProfileProvider).valueOrNull;
    final async = ref.watch(chemistDashboardProvider);
    final d = async.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: LiveRefresh(
          onRefresh: () => ref.refresh(chemistDashboardProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(
                child: GreetingHeader(
                  name: (pharmacy?.businessName ?? '').trim().isEmpty
                      ? 'Welcome'
                      : pharmacy!.businessName,
                  subtitle: d == null
                      ? 'Here\'s how your pharmacy is doing.'
                      : d.waiting > 0
                      ? '${d.waiting} new ${d.waiting == 1 ? 'order is' : 'orders are'} waiting for you.'
                      : d.openOrders > 0
                      ? '${d.openOrders} ${d.openOrders == 1 ? 'order' : 'orders'} on the go.'
                      : 'All caught up. Here\'s how your pharmacy is doing.',
                  avatarPath: ref
                      .watch(currentAppUserProvider)
                      .valueOrNull
                      ?.avatarUrl,
                  onAvatarTap: () => context.go('/chemist/account'),
                  actions: [
                    NotificationBell(
                      count: ref.watch(unreadNotificationCountProvider),
                      onPressed: () => context.push('/chemist/notifications'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...async.when(
                skipLoadingOnRefresh: true,
                skipLoadingOnReload: true,
                loading: () => const [
                  SizedBox(
                    height: 500,
                    child: SkeletonList(itemCount: 5, padding: EdgeInsets.zero),
                  ),
                ],
                error: (e, _) => [
                  ErrorView(
                    message: friendlyError(e),
                    onRetry: () => ref.invalidate(chemistDashboardProvider),
                  ),
                ],
                data: (d) => _sections(context, ref, d),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(
    BuildContext context,
    WidgetRef ref,
    ChemistDashboard d,
  ) {
    var i = 0;
    Widget item(Widget child) => FadeSlideIn(index: i++, child: child);
    return [
      if (d.openOrders > 0 || d.disputed > 0) ...[
        item(_NeedsYou(d: d)),
        const SizedBox(height: 14),
      ],
      item(_SalesCard(d: d)),
      const SizedBox(height: 22),
      item(
        _Heading(
          'Stock health',
          action: 'Manage stock',
          onAction: () => context.go('/chemist/stock'),
        ),
      ),
      item(_StockHealth(d: d)),
      if (d.lowStock.isNotEmpty) ...[
        const SizedBox(height: 22),
        item(
          _Heading(
            'Restock soon',
            subtitle: 'Running low or selling fast',
            action: 'Update',
            onAction: () => context.go('/chemist/stock'),
          ),
        ),
        item(
          _ListCard(
            children: [
              for (final s in d.lowStock)
                _StatRow(
                  icon: LucideIcons.trendingDown,
                  color: AppColors.warning,
                  title: s.name,
                  subtitle: s.daysLeft != null && s.daysLeft! <= 30
                      ? '${s.quantity} left · about ${s.daysLeft} '
                            '${s.daysLeft == 1 ? 'day' : 'days'} at this pace'
                      : '${s.quantity} left',
                ),
            ],
          ),
        ),
      ],
      if (d.outOfStock.isNotEmpty) ...[
        const SizedBox(height: 22),
        item(
          _Heading(
            'Out of stock',
            subtitle: 'These were on your shelf and have run out',
            action: 'Restock',
            onAction: () => context.go('/chemist/stock'),
          ),
        ),
        item(
          _ListCard(
            children: [
              for (final s in d.outOfStock)
                _StatRow(
                  icon: LucideIcons.packageX,
                  color: AppColors.danger,
                  title: s.name,
                  subtitle: s.units > 0
                      ? 'Sold ${s.units} in the last 30 days: patients want it'
                      : s.since != null
                      ? 'Out since ${DateFormat('d MMM').format(s.since!.toLocal())}'
                      : 'None left',
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      item(const _Heading('Best sellers', subtitle: 'Last 30 days')),
      item(_BestSellers(top: d.top)),
      if (d.slow.isNotEmpty) ...[
        const SizedBox(height: 22),
        item(
          const _Heading(
            'Not selling',
            subtitle: 'In stock but no sales in 30 days',
          ),
        ),
        item(
          _ListCard(
            children: [
              for (final s in d.slow)
                _StatRow(
                  icon: LucideIcons.hourglass,
                  color: AppColors.inkSoft,
                  title: s.name,
                  subtitle: '${s.quantity} on the shelf',
                  trailing: formatKes(s.value),
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 22),
      item(const _Heading('What patients say')),
      item(const _MyReviews()),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.subtitle, this.action, this.onAction});

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
              ],
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// New / preparing / ready counts, straight to the orders.
class _NeedsYou extends StatelessWidget {
  const _NeedsYou({required this.d});

  final ChemistDashboard d;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, int n, Color color, IconData icon) => Expanded(
      child: Material(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.go('/chemist/orders'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const Spacer(),
                    if (n > 0 && color == AppColors.primary)
                      PulseDot(color: color, size: 8),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$n',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile('New', d.waiting, AppColors.primary, LucideIcons.bellRing),
            const SizedBox(width: 10),
            tile(
              'Preparing',
              d.preparing,
              AppColors.warning,
              LucideIcons.pillBottle,
            ),
            const SizedBox(width: 10),
            tile('Ready', d.ready, AppColors.success, LucideIcons.packageCheck),
          ],
        ),
        if (d.disputed > 0) ...[
          const SizedBox(height: 10),
          Material(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14),
            child: ListTile(
              dense: true,
              leading: const Icon(LucideIcons.flag, color: AppColors.danger),
              title: Text(
                '${d.disputed} ${d.disputed == 1 ? 'order has' : 'orders have'} a problem reported',
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
              onTap: () => context.go('/chemist/orders'),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sales over 30 days with the trend, today and this week, and the last
/// 14 days as bars.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.d});

  final ChemistDashboard d;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trend = d.trend;
    const white70 = Color(0xB3FFFFFF);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sales · last 30 days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelLarge?.copyWith(color: white70),
                ),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x26FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        trend >= 0
                            ? LucideIcons.trendingUp
                            : LucideIcons.trendingDown,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${trend >= 0 ? '+' : ''}${(trend * 100).round()}%',
                        style: text.labelMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          CountUp(
            value: d.salesMonth,
            format: (v) => formatKes(v.toDouble()),
            style: text.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(label: 'Today', value: formatKes(d.salesToday)),
              _MiniStat(label: '7 days', value: formatKes(d.salesWeek)),
              _MiniStat(label: 'Orders', value: '${d.ordersMonth}'),
              _MiniStat(label: 'Avg order', value: formatKes(d.averageOrder)),
            ],
          ),
          const SizedBox(height: 16),
          _Bars(days: d.daily),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(LucideIcons.wallet, size: 14, color: white70),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${formatKes(d.released)} paid out · ${formatKes(d.held)} '
                  'held until patients confirm',
                  style: text.bodySmall?.copyWith(color: white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            label,
            style: text.labelSmall?.copyWith(color: const Color(0xB3FFFFFF)),
          ),
        ],
      ),
    );
  }
}

/// Fourteen small bars, today on the right.
class _Bars extends StatelessWidget {
  const _Bars({required this.days});

  final List<DaySales> days;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final top = days.fold<double>(0, (m, d) => d.revenue > m ? d.revenue : m);
    final label = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: const Color(0x99FFFFFF),
      fontSize: 9,
    );
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Tooltip(
                message:
                    '${DateFormat('EEE d MMM').format(days[i].day)}: '
                    '${formatKes(days[i].revenue)} · ${days[i].orders} orders',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: top <= 0 ? 0 : days[i].revenue / top,
                      ),
                      duration: Duration(milliseconds: 500 + i * 30),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Container(
                        height: 4 + 58 * v,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == days.length - 1
                              ? Colors.white
                              : const Color(0x80FFFFFF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('E').format(days[i].day).substring(0, 1),
                      style: label,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StockHealth extends StatelessWidget {
  const _StockHealth({required this.d});

  final ChemistDashboard d;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, Color color, IconData icon) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            tile(
              'In stock',
              '${d.inStock}',
              AppColors.success,
              LucideIcons.packageCheck,
            ),
            const SizedBox(width: 10),
            tile(
              'Running low',
              '${d.low}',
              AppColors.warning,
              LucideIcons.trendingDown,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            tile(
              'Out of stock',
              '${d.out}',
              AppColors.danger,
              LucideIcons.packageX,
            ),
            const SizedBox(width: 10),
            tile(
              'Stock value',
              formatKes(d.stockValue),
              AppColors.primary,
              LucideIcons.wallet,
            ),
          ],
        ),
      ],
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: text.labelLarge),
          ],
        ],
      ),
    );
  }
}

class _BestSellers extends StatelessWidget {
  const _BestSellers({required this.top});

  final List<StockStat> top;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (top.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySofter,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'Your best sellers will show here after your first orders.',
          style: text.bodyMedium,
        ),
      );
    }
    final most = top.first.units == 0 ? 1 : top.first.units;
    return _ListCard(
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${i + 1}',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: i == 0 ? AppColors.primary : AppColors.inkFaint,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        top[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: top[i].units / most,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${top[i].units} sold · ${top[i].quantity} left',
                        style: text.labelSmall?.copyWith(
                          color: top[i].quantity == 0
                              ? AppColors.danger
                              : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(formatKes(top[i].revenue), style: text.labelLarge),
              ],
            ),
          ),
      ],
    );
  }
}

class _MyReviews extends ConsumerWidget {
  const _MyReviews();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final rating = ref.watch(_myRatingProvider).valueOrNull;
    final reviews = ref.watch(_myReviewsProvider).valueOrNull ?? const [];
    if (rating == null || rating.count == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primarySofter,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          'No reviews yet. Patients can rate you after they confirm they got '
          'their order, and reviews show on your public page.',
          style: text.bodyMedium,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Text(
                rating.avg.toStringAsFixed(1),
                style: text.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingStars(rating: rating.avg, size: 16),
                    const SizedBox(height: 4),
                    Text(
                      'Average of ${rating.count} '
                      '${rating.count == 1 ? 'review' : 'reviews'} · shown on '
                      'your public page',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final r in reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ReviewCard(review: r),
          ),
      ],
    );
  }
}
