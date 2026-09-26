import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/admin_charts.dart';
import '../widgets/admin_ui.dart';

typedef ActivityFilter = ({String? table, String? op, int limit});

/// Fires whenever anything is written to the database (realtime).
final activityTickProvider = StreamProvider.autoDispose<int>(
  (ref) => ref
      .watch(adminRepositoryProvider)
      .watchActivity()
      .map((rows) => rows.isEmpty ? 0 : (rows.first['id'] as num).toInt()),
);

final activityProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ActivityFilter>(
      (ref, f) => ref
          .watch(adminRepositoryProvider)
          .activity(table: f.table, op: f.op, limit: f.limit),
    );

final sessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) => ref.watch(adminRepositoryProvider).sessions(limit: 200),
);

final _tableNamesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final stats = await ref.watch(adminRepositoryProvider).dbStats();
  return [
    for (final t in (stats['tables'] as List).cast<Map<String, dynamic>>())
      t['name'] as String,
  ]..sort();
});

/// "Live traffic": every insert, update and delete hitting the database as
/// it happens (who, which table, which row, which columns), and every
/// signed-in device.
class AdminActivityScreen extends StatelessWidget {
  const AdminActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: ColoredBox(
        color: AdminColors.page,
        child: Column(
          children: [
            Material(
              color: AppColors.white,
              child: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Database writes'),
                  Tab(text: 'Signed-in devices'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(children: [_WritesTab(), _SessionsTab()]),
            ),
          ],
        ),
      ),
    );
  }
}

class _WritesTab extends ConsumerStatefulWidget {
  const _WritesTab();

  @override
  ConsumerState<_WritesTab> createState() => _WritesTabState();
}

class _WritesTabState extends ConsumerState<_WritesTab> {
  String? _table;
  String? _op;
  int _limit = 100;
  bool _live = true;

  ActivityFilter get _filter => (table: _table, op: _op, limit: _limit);

  @override
  Widget build(BuildContext context) {
    ref.listen(activityTickProvider, (_, _) {
      if (_live) ref.invalidate(activityProvider(_filter));
    });
    final async = ref.watch(activityProvider(_filter));
    final rows = async.valueOrNull ?? const <Map<String, dynamic>>[];
    final tables = ref.watch(_tableNamesProvider).valueOrNull ?? const [];

    final byOp = <String, int>{};
    final byTable = <String, int>{};
    for (final r in rows) {
      byOp.update(r['op'] as String, (v) => v + 1, ifAbsent: () => 1);
      byTable.update(
        r['table_name'] as String,
        (v) => v + 1,
        ifAbsent: () => 1,
      );
    }
    final topTables = byTable.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AdminPage(
      title: 'Live traffic',
      subtitle:
          'Every insert, update and delete in the database, newest first. Values are not stored, only which columns changed.',
      actions: [
        FilterChip(
          avatar: Icon(
            _live ? LucideIcons.radio : LucideIcons.pause,
            size: 16,
            color: _live ? AdminColors.good : AppColors.inkSoft,
          ),
          label: Text(_live ? 'Live' : 'Paused'),
          selected: _live,
          onSelected: (v) {
            setState(() => _live = v);
            if (v) ref.invalidate(activityProvider(_filter));
          },
        ),
        IconButton.outlined(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(activityProvider(_filter)),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
        ),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownMenu<String?>(
              initialSelection: _table,
              label: const Text('Table'),
              width: 220,
              dropdownMenuEntries: [
                const DropdownMenuEntry(value: null, label: 'All tables'),
                for (final t in tables) DropdownMenuEntry(value: t, label: t),
              ],
              onSelected: (v) => setState(() => _table = v),
            ),
            FilterRow<String>(
              value: _op,
              allLabel: 'All operations',
              options: const [
                ('INSERT', 'Inserts'),
                ('UPDATE', 'Updates'),
                ('DELETE', 'Deletes'),
              ],
              onChanged: (v) => setState(() => _op = v),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ResponsiveGrid(
          minWidth: 320,
          children: [
            AdminCard(
              title: 'In this view',
              subtitle: '${rows.length} most recent writes',
              child: StackedShareBar(
                segments: [
                  ('Inserts', byOp['INSERT'] ?? 0, AdminColors.series1),
                  ('Updates', byOp['UPDATE'] ?? 0, AdminColors.series2),
                  ('Deletes', byOp['DELETE'] ?? 0, AdminColors.series3),
                ],
              ),
            ),
            AdminCard(
              title: 'Busiest tables',
              subtitle: 'In this view',
              child: BarList(
                items: [for (final e in topTables.take(5)) (e.key, e.value)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (async.hasError && rows.isEmpty)
          ErrorView(
            message: friendlyError(async.error!),
            onRetry: () => ref.invalidate(activityProvider(_filter)),
          )
        else
          AdminTable(
            loading: async.isLoading,
            rows: rows,
            emptyMessage: 'No database writes match these filters yet.',
            onTapRow: (r) {
              final actor = r['actor_id'];
              if (actor != null) context.go('/admin/users/$actor');
            },
            columns: activityColumns,
          ),
        if (rows.length >= _limit)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Center(
              child: TextButton(
                onPressed: () => setState(() => _limit += 100),
                child: const Text('Load more'),
              ),
            ),
          ),
      ],
    );
  }
}

/// Columns for activity-log rows (also used on the user page).
final activityColumns = <AdminColumn>[
  AdminColumn(
    'When',
    (r) => TwoLine(
      DateFormat('HH:mm:ss').format(parseTime(r['at'])!),
      ago(parseTime(r['at'])),
    ),
    width: 110,
  ),
  AdminColumn('Operation', (r) => OpChip(r['op'] as String), width: 110),
  AdminColumn('Table', (r) => CellText('${r['table_name']}', mono: true)),
  AdminColumn(
    'Row',
    (r) => CellText(shortId(r['row_id']), mono: true),
    width: 100,
  ),
  AdminColumn(
    'Changed',
    (r) => CellText(
      ((r['changed'] as List?) ?? const []).join(', ').isEmpty
          ? '—'
          : ((r['changed'] as List?) ?? const []).join(', '),
    ),
    width: 220,
  ),
  AdminColumn(
    'By',
    (r) => TwoLine(
      (r['actor_name'] as String?) ?? 'System',
      humanize(r['actor_role']),
    ),
    width: 180,
  ),
];

/// INSERT / UPDATE / DELETE with an icon (never colour alone).
class OpChip extends StatelessWidget {
  const OpChip(this.op, {super.key});

  final String op;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (op) {
      'INSERT' => ('Insert', LucideIcons.plus, AdminColors.good),
      'DELETE' => ('Delete', LucideIcons.trash2, AdminColors.critical),
      _ => ('Update', LucideIcons.pencil, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact live list of the latest writes (for the overview).
class RecentActivityList extends ConsumerWidget {
  const RecentActivityList({super.key, this.limit = 8});

  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = (table: null, op: null, limit: limit);
    ref.listen(activityTickProvider, (_, _) {
      ref.invalidate(activityProvider(filter));
    });
    final rows = ref.watch(activityProvider(filter)).valueOrNull;
    final theme = Theme.of(context).textTheme;
    if (rows == null) return const SizedBox(height: 120, child: LoadingView());
    if (rows.isEmpty) {
      return Text('No activity yet.', style: theme.bodySmall);
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                OpChip(r['op'] as String),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: (r['actor_name'] as String?) ?? 'System',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: ' · ${r['table_name']}'),
                        if (((r['changed'] as List?) ?? const []).isNotEmpty)
                          TextSpan(
                            text: ' (${(r['changed'] as List).join(', ')})',
                            style: const TextStyle(color: AppColors.inkSoft),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: AppColors.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Text(ago(parseTime(r['at'])), style: theme.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _SessionsTab extends ConsumerWidget {
  const _SessionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(sessionsProvider);
    final rows = async.valueOrNull ?? const <Map<String, dynamic>>[];
    final now = DateTime.now();
    final active1h = rows.where((r) {
      final t = parseTime(r['last_active']);
      return t != null && now.difference(t).inMinutes < 60;
    }).length;

    return AdminPage(
      title: 'Signed-in devices',
      subtitle:
          '${rows.length} sessions · $active1h active in the last hour. Suspending a user ends all of their sessions.',
      actions: [
        IconButton.outlined(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(sessionsProvider),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
        ),
      ],
      children: [
        if (async.hasError && rows.isEmpty)
          ErrorView(
            message: friendlyError(async.error!),
            onRetry: () => ref.invalidate(sessionsProvider),
          )
        else
          AdminTable(
            loading: async.isLoading,
            rows: rows,
            emptyMessage: 'Nobody is signed in.',
            onTapRow: (r) => context.go('/admin/users/${r['user_id']}'),
            columns: [
              AdminColumn(
                'User',
                (r) => TwoLine('${r['name']}', humanize(r['role'])),
                width: 200,
              ),
              AdminColumn(
                'Device',
                (r) => CellText(describeDevice(r['user_agent'] as String?)),
                width: 200,
              ),
              AdminColumn(
                'IP address',
                (r) => CellText('${r['ip'] ?? '—'}', mono: true),
                width: 140,
              ),
              AdminColumn(
                'Signed in',
                (r) => CellText(stamp(parseTime(r['created_at']))),
              ),
              AdminColumn(
                'Last active',
                (r) => CellText(ago(parseTime(r['last_active']))),
              ),
            ],
          ),
      ],
    );
  }
}

/// "Chrome on Windows", "GoDoctor app (Android)", ...
String describeDevice(String? ua) {
  if (ua == null || ua.isEmpty) return 'Unknown device';
  final os = ua.contains('Android')
      ? 'Android'
      : ua.contains('iPhone') || ua.contains('iPad')
      ? 'iOS'
      : ua.contains('Windows')
      ? 'Windows'
      : ua.contains('Mac OS')
      ? 'macOS'
      : ua.contains('Linux')
      ? 'Linux'
      : null;
  if (ua.startsWith('Dart/') || ua.contains('dart:io')) {
    return 'GoDoctor app${os == null ? '' : ' ($os)'}';
  }
  final browser = ua.contains('Edg/')
      ? 'Edge'
      : ua.contains('Chrome/')
      ? 'Chrome'
      : ua.contains('Firefox/')
      ? 'Firefox'
      : ua.contains('Safari/')
      ? 'Safari'
      : 'Browser';
  return os == null ? browser : '$browser on $os';
}
