import 'dart:convert';

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

final dbStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(adminRepositoryProvider).dbStats(),
);

typedef TableQuery = ({String table, int page});

final tableRowsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, TableQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .tableRows(q.table, limit: 50, offset: q.page * 50),
    );

/// Database health: size, connections, cache hit rate, every table's row
/// count / size / read-write traffic, and the most expensive queries.
class AdminDatabaseScreen extends ConsumerWidget {
  const AdminDatabaseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dbStatsProvider);
    final d = async.valueOrNull;
    final theme = Theme.of(context).textTheme;

    final actions = [
      IconButton.outlined(
        tooltip: 'Refresh',
        onPressed: () => ref.invalidate(dbStatsProvider),
        icon: const Icon(LucideIcons.refreshCw, size: 18),
      ),
    ];
    if (d == null) {
      return AdminPage(
        title: 'Database',
        actions: actions,
        children: [
          if (async.hasError)
            ErrorView(
              message: friendlyError(async.error!),
              onRetry: () => ref.invalidate(dbStatsProvider),
            )
          else
            const SizedBox(height: 300, child: LoadingView()),
        ],
      );
    }

    final tables = ((d['tables'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final queries = ((d['top_queries'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final conns = (d['connections'] as Map?)?.cast<String, dynamic>() ?? {};
    final totalConns = conns.values.fold<num>(0, (s, v) => s + asNum(v));
    final rows = tables.fold<num>(0, (s, t) => s + asNum(t['rows']));
    final writes = tables.fold<num>(
      0,
      (s, t) =>
          s + asNum(t['inserts']) + asNum(t['updates']) + asNum(t['deletes']),
    );
    final byRows = [...tables]
      ..sort((a, b) => asNum(b['rows']).compareTo(asNum(a['rows'])));

    return AdminPage(
      title: 'Database',
      subtitle: 'PostgreSQL ${d['postgres_version']} on Supabase',
      actions: actions,
      onRefresh: () async => ref.invalidate(dbStatsProvider),
      children: [
        ResponsiveGrid(
          minWidth: 200,
          children: [
            StatTile(
              label: 'Database size',
              value: bytes(asNum(d['db_size_bytes'])),
              icon: LucideIcons.hardDrive,
              caption: '${tables.length} tables',
            ),
            StatTile(
              label: 'Rows stored',
              value: compactNumber(rows),
              icon: LucideIcons.tableProperties,
              caption: 'Across all app tables',
            ),
            StatTile(
              label: 'Writes since stats reset',
              value: compactNumber(writes),
              icon: LucideIcons.pencil,
              caption: 'Inserts + updates + deletes',
            ),
            StatTile(
              label: 'Connections',
              value: compactNumber(totalConns),
              icon: LucideIcons.server,
              caption: conns.entries
                  .map((e) => '${compactNumber(asNum(e.value))} ${e.key}')
                  .join(' · '),
            ),
            StatTile(
              label: 'Cache hit rate',
              value: d['cache_hit_ratio'] == null
                  ? '—'
                  : '${(asNum(d['cache_hit_ratio']) * 100).toStringAsFixed(1)}%',
              icon: LucideIcons.gauge,
              caption: 'Reads served from memory (aim for 99%+)',
            ),
          ],
        ),
        const SizedBox(height: 14),
        AdminCard(
          title: 'Largest tables by rows',
          child: BarList(
            items: [
              for (final t in byRows.take(8))
                ('${t['name']}', asNum(t['rows'])),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Tables', style: theme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Tap a table to browse its rows (read-only).',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 8),
        AdminTable(
          rows: tables,
          onTapRow: (t) => context.go('/admin/database/${t['name']}'),
          columns: [
            AdminColumn(
              'Table',
              (t) => CellText('${t['name']}', mono: true),
              width: 200,
            ),
            AdminColumn(
              'Rows',
              (t) => CellText(compactNumber(asNum(t['rows']))),
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              'Size',
              (t) => CellText(bytes(asNum(t['size_bytes']))),
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              'Inserts',
              (t) => CellText(compactNumber(asNum(t['inserts']))),
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              'Updates',
              (t) => CellText(compactNumber(asNum(t['updates']))),
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              'Deletes',
              (t) => CellText(compactNumber(asNum(t['deletes']))),
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              'Index scans',
              (t) => CellText(compactNumber(asNum(t['index_scans']))),
              width: 110,
              numeric: true,
            ),
            AdminColumn(
              'Full scans',
              (t) => CellText(compactNumber(asNum(t['seq_scans']))),
              width: 100,
              numeric: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Most expensive queries', style: theme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'From pg_stat_statements: the queries the app runs, ranked by total time spent.',
          style: theme.bodySmall,
        ),
        const SizedBox(height: 8),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final q in queries)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    '${q['query']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: AppColors.ink,
                    ),
                  ),
                  subtitle: Text(
                    '${compactNumber(asNum(q['calls']))} calls · '
                    '${asNum(q['mean_ms']).toStringAsFixed(2)} ms avg · '
                    '${compactNumber(asNum(q['total_ms']))} ms total · '
                    '${compactNumber(asNum(q['rows']))} rows',
                    style: theme.bodySmall,
                  ),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SelectableText(
                          '${q['query']}',
                          style: theme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Read-only rows of one table, like a database table editor.
class AdminTableBrowserScreen extends ConsumerStatefulWidget {
  const AdminTableBrowserScreen({super.key, required this.table});

  final String table;

  @override
  ConsumerState<AdminTableBrowserScreen> createState() =>
      _AdminTableBrowserScreenState();
}

class _AdminTableBrowserScreenState
    extends ConsumerState<AdminTableBrowserScreen> {
  int _page = 0;
  Map<String, dynamic>? _last;

  static String _cell(Object? v) => switch (v) {
    null => 'NULL',
    final String s => s,
    final num n => '$n',
    final bool b => '$b',
    _ => jsonEncode(v),
  };

  @override
  Widget build(BuildContext context) {
    final q = (table: widget.table, page: _page);
    final async = ref.watch(tableRowsProvider(q));
    if (async.hasValue) _last = async.value;
    final d = async.valueOrNull ?? _last;
    final cols = ((d?['columns'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final rows = ((d?['rows'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

    return AdminPage(
      title: widget.table,
      subtitle: d == null
          ? 'Loading…'
          : '${compactNumber(asNum(d['total']))} rows · ${cols.length} columns · read-only',
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => context.go('/admin/database'),
          icon: const Icon(LucideIcons.chevronLeft, size: 16),
          label: const Text('All tables'),
        ),
        IconButton.outlined(
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(tableRowsProvider(q)),
          icon: const Icon(LucideIcons.refreshCw, size: 18),
        ),
      ],
      children: [
        if (async.hasError && d == null)
          ErrorView(
            message: friendlyError(async.error!),
            onRetry: () => ref.invalidate(tableRowsProvider(q)),
          )
        else
          AdminTable(
            loading: async.isLoading,
            rows: rows,
            total: d == null ? null : asNum(d['total']).toInt(),
            page: _page,
            onPage: (p) => setState(() => _page = p),
            onTapRow: (r) => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('${widget.table} row'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(r),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            columns: [
              for (final c in cols)
                AdminColumn(
                  '${c['name']}',
                  (r) => CellText(_cell(r[c['name']]), mono: true),
                  width: switch ('${c['type']}') {
                    'uuid' => 150,
                    'boolean' => 90,
                    'integer' || 'bigint' || 'numeric' => 100,
                    'text' => 200,
                    _ => 170,
                  },
                ),
            ],
          ),
      ],
    );
  }
}
