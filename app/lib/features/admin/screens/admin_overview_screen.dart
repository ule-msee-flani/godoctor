import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_ui.dart';
import 'admin_activity_screen.dart';

final adminRangeProvider = StateProvider<int>((ref) => 30);

/// Dashboard numbers for the chosen range; refreshes itself every 30 s.
final adminOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) {
  final days = ref.watch(adminRangeProvider);
  final timer = Timer(const Duration(seconds: 30), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return ref.watch(adminRepositoryProvider).overview(days: days);
});

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(adminRangeProvider);
    final async = ref.watch(adminOverviewProvider);
    final data = async.valueOrNull;

    final filters = [
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 1, label: Text('Today')),
          ButtonSegment(value: 7, label: Text('7 days')),
          ButtonSegment(value: 30, label: Text('30 days')),
          ButtonSegment(value: 90, label: Text('90 days')),
        ],
        selected: {days},
        showSelectedIcon: false,
        onSelectionChanged: (s) =>
            ref.read(adminRangeProvider.notifier).state = s.first,
      ),
      IconButton.outlined(
        tooltip: 'Refresh',
        onPressed: () => ref.invalidate(adminOverviewProvider),
        icon: const Icon(LucideIcons.refreshCw, size: 18),
      ),
    ];

    if (data == null) {
      return AdminPage(
        title: 'Overview',
        subtitle: 'Everything happening on GoDoctor',
        actions: filters,
        children: [
          if (async.hasError)
            ErrorView(
              message: friendlyError(async.error!),
              onRetry: () => ref.invalidate(adminOverviewProvider),
            )
          else
            const SizedBox(height: 300, child: LoadingView()),
        ],
      );
    }

    // Keep showing the last numbers (dimmed) while a new range loads.
    return AnimatedOpacity(
      opacity: async.isRefreshing || async.isReloading ? 0.6 : 1,
      duration: const Duration(milliseconds: 150),
      child: _Body(data: data, days: days, filters: filters),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.data, required this.days, required this.filters});

  final Map<String, dynamic> data;
  final int days;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    num n(String k) => asNum(data[k]);
    Map<String, dynamic> m(String k) =>
        (data[k] as Map?)?.cast<String, dynamic>() ?? const {};
    final period = days == 1 ? 'today' : 'last $days days';

    final series = ((data['series'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    List<SeriesPoint> points(String key) => [
      for (final r in series)
        SeriesPoint(DateTime.parse(r['day'] as String), asNum(r[key])),
    ];

    final roles = m('users_by_role');
    final consultStatus = m('consults_by_status').entries.toList()
      ..sort((a, b) => asNum(b.value).compareTo(asNum(a.value)));
    final orderStatus = m('orders_by_status').entries.toList()
      ..sort((a, b) => asNum(b.value).compareTo(asNum(a.value)));

    return AdminPage(
      title: 'Overview',
      subtitle: 'Everything happening on GoDoctor · $period',
      actions: filters,
      onRefresh: () async => ref.invalidate(adminOverviewProvider),
      children: [
        const _SectionLabel('Right now'),
        ResponsiveGrid(
          minWidth: 200,
          children: [
            StatTile(
              label: 'People online',
              value: compactNumber(n('online_now')),
              icon: LucideIcons.radio,
              caption:
                  '${compactNumber(n('sessions_active'))} signed-in devices (24 h)',
              onTap: () => context.go('/admin/activity'),
            ),
            StatTile(
              label: 'Live consultations',
              value: compactNumber(n('consults_live')),
              icon: LucideIcons.video,
              caption:
                  '${compactNumber(n('consults_awaiting_payment'))} waiting for payment',
              onTap: () => context.go('/admin/consultations'),
            ),
            StatTile(
              label: 'Doctors available',
              value: compactNumber(n('doctors_available')),
              icon: LucideIcons.stethoscope,
              caption: '${compactNumber(n('doctors_busy'))} in a consultation',
            ),
            StatTile(
              label: 'Database writes (24 h)',
              value: compactNumber(n('writes_24h')),
              icon: LucideIcons.database,
              caption: 'Database size ${bytes(n('db_size_bytes'))}',
              onTap: () => context.go('/admin/database'),
            ),
          ],
        ),
        _SectionLabel('This period ($period)'),
        ResponsiveGrid(
          minWidth: 200,
          children: [
            StatTile(
              label: 'Revenue',
              value: kes(n('revenue')),
              icon: LucideIcons.wallet,
              current: n('revenue'),
              previous: n('revenue_prev'),
              onTap: () => context.go('/admin/payments'),
            ),
            StatTile(
              label: 'New users',
              value: compactNumber(n('users_new')),
              icon: LucideIcons.userPlus,
              current: n('users_new'),
              previous: n('users_new_prev'),
              onTap: () => context.go('/admin/users'),
            ),
            StatTile(
              label: 'Consultations',
              value: compactNumber(n('consults')),
              icon: LucideIcons.stethoscope,
              current: n('consults'),
              previous: n('consults_prev'),
              onTap: () => context.go('/admin/consultations'),
            ),
            StatTile(
              label: 'Medicine orders',
              value: compactNumber(n('orders')),
              icon: LucideIcons.shoppingBag,
              current: n('orders'),
              previous: n('orders_prev'),
              onTap: () => context.go('/admin/orders'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minWidth: 420,
          children: [
            TimeSeriesCard(
              title: 'Revenue per day',
              headline:
                  '${kes(n('revenue'))} · consultations ${kes(n('revenue_consults'))}, medicines ${kes(n('revenue_orders'))}',
              points: points('revenue'),
              form: SeriesForm.area,
              valueFormat: (v) => compactNumber(v),
            ),
            TimeSeriesCard(
              title: 'Consultations per day',
              headline: '${compactNumber(n('consults'))} in total',
              points: points('consults'),
              form: SeriesForm.columns,
            ),
            TimeSeriesCard(
              title: 'New users per day',
              headline: '${compactNumber(n('users_new'))} joined',
              points: points('signups'),
              form: SeriesForm.columns,
            ),
            TimeSeriesCard(
              title: 'Database writes per day',
              headline: 'Inserts, updates and deletes across all tables',
              points: points('writes'),
              form: SeriesForm.area,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minWidth: 320,
          children: [
            AdminCard(
              title: 'Users by role',
              subtitle: '${compactNumber(n('users_total'))} accounts in total',
              child: StackedShareBar(
                segments: [
                  ('Patients', asNum(roles['patient']), AdminColors.series1),
                  ('Doctors', asNum(roles['doctor']), AdminColors.series2),
                  ('Chemists', asNum(roles['chemist']), AdminColors.series3),
                  ('Admins', asNum(roles['admin']), AdminColors.series4),
                ],
              ),
            ),
            AdminCard(
              title: 'Consultations by status',
              subtitle: period,
              child: BarList(
                items: [
                  for (final e in consultStatus)
                    (humanize(e.key), asNum(e.value)),
                ],
              ),
            ),
            AdminCard(
              title: 'Orders by status',
              subtitle: period,
              child: BarList(
                items: [
                  for (final e in orderStatus)
                    (humanize(e.key), asNum(e.value)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minWidth: 420,
          children: [
            AdminCard(
              title: 'Needs attention',
              child: Column(
                children: [
                  _AttentionRow(
                    icon: LucideIcons.stethoscope,
                    label: 'Doctors waiting for licence verification',
                    count: n('pending_doctors'),
                    onTap: () => context.go('/admin/verification'),
                  ),
                  _AttentionRow(
                    icon: LucideIcons.store,
                    label: 'Chemists waiting for verification',
                    count: n('pending_chemists'),
                    onTap: () => context.go('/admin/verification'),
                  ),
                  _AttentionRow(
                    icon: LucideIcons.headset,
                    label: 'Support messages waiting for a reply',
                    count: n('tickets_open'),
                    onTap: () => context.go('/admin/support'),
                  ),
                  _AttentionRow(
                    icon: LucideIcons.ban,
                    label: 'Suspended accounts',
                    count: n('users_suspended'),
                    onTap: () => context.go('/admin/users'),
                  ),
                  _AttentionRow(
                    icon: LucideIcons.star,
                    label: n('rating_count') == 0
                        ? 'No app ratings yet'
                        : 'App rating ${asNum(data['rating_avg']).toStringAsFixed(1)} / 5 (${compactNumber(n('rating_count'))} ratings)',
                    count: null,
                    onTap: () => context.go('/admin/support'),
                  ),
                ],
              ),
            ),
            AdminCard(
              title: 'Latest activity',
              subtitle: 'Most recent writes to the database',
              trailing: TextButton(
                onPressed: () => context.go('/admin/activity'),
                child: const Text('Open live traffic'),
              ),
              child: const RecentActivityList(limit: 8),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: AppColors.inkSoft,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final num? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hot = (count ?? 0) > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: theme.bodyMedium)),
            if (count != null)
              hot
                  ? StatusChip(compactNumber(count!), tone: Tone.warning)
                  : const StatusChip('0', tone: Tone.good),
            const SizedBox(width: 6),
            const Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: AppColors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
