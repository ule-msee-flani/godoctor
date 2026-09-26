import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/admin_ui.dart';

const _pageSize = 50;

typedef RecordQuery = ({String? search, String? status, int page});

final consultationsPageProvider = FutureProvider.autoDispose
    .family<AdminRows, RecordQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .consultations(
            search: q.search,
            status: q.status,
            limit: _pageSize,
            offset: q.page * _pageSize,
          ),
    );

final ordersPageProvider = FutureProvider.autoDispose
    .family<AdminRows, RecordQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .orders(
            search: q.search,
            status: q.status,
            limit: _pageSize,
            offset: q.page * _pageSize,
          ),
    );

final paymentsPageProvider = FutureProvider.autoDispose
    .family<AdminRows, RecordQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .payments(
            status: q.status,
            limit: _pageSize,
            offset: q.page * _pageSize,
          ),
    );

/// Shared frame for a searchable, filterable, paged record list.
class _RecordList extends ConsumerStatefulWidget {
  const _RecordList({
    required this.title,
    required this.subtitle,
    required this.provider,
    required this.statuses,
    required this.columns,
    this.searchHint,
    this.onTapRow,
    this.header,
  });

  final String title;
  final String subtitle;
  final AutoDisposeFutureProviderFamily<AdminRows, RecordQuery> provider;
  final List<(String, String)> statuses;
  final List<AdminColumn> columns;
  final String? searchHint;
  final void Function(
    BuildContext,
    WidgetRef,
    Map<String, dynamic>,
    VoidCallback refresh,
  )?
  onTapRow;
  final Widget Function(AdminRows? page)? header;

  @override
  ConsumerState<_RecordList> createState() => _RecordListState();
}

class _RecordListState extends ConsumerState<_RecordList> {
  String? _search;
  String? _status;
  int _page = 0;
  AdminRows? _last;

  RecordQuery get _q => (search: _search, status: _status, page: _page);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(widget.provider(_q));
    if (async.hasValue) _last = async.value;
    final page = async.valueOrNull ?? _last;
    void refresh() => ref.invalidate(widget.provider(_q));

    return AdminPage(
      title: widget.title,
      subtitle: page == null
          ? widget.subtitle
          : '${widget.subtitle} · ${compactNumber(page.total)} found',
      onRefresh: () async => refresh(),
      actions: [
        if (widget.searchHint != null)
          AdminSearchField(
            hint: widget.searchHint!,
            onSubmitted: (v) => setState(() {
              _search = v.trim().isEmpty ? null : v.trim();
              _page = 0;
            }),
          ),
        IconButton.outlined(
          tooltip: 'Refresh',
          onPressed: refresh,
          icon: const Icon(LucideIcons.refreshCw, size: 18),
        ),
      ],
      children: [
        ?widget.header?.call(page),
        FilterRow<String>(
          value: _status,
          allLabel: 'All statuses',
          options: widget.statuses,
          onChanged: (v) => setState(() {
            _status = v;
            _page = 0;
          }),
        ),
        const SizedBox(height: 14),
        if (async.hasError && page == null)
          ErrorView(message: friendlyError(async.error!), onRetry: refresh)
        else
          AdminTable(
            loading: async.isLoading,
            rows: page?.rows ?? const [],
            total: page?.total,
            page: _page,
            pageSize: _pageSize,
            onPage: (p) => setState(() => _page = p),
            onTapRow: widget.onTapRow == null
                ? null
                : (r) => widget.onTapRow!(context, ref, r, refresh),
            columns: widget.columns,
          ),
      ],
    );
  }
}

Future<void> _act(
  BuildContext context,
  Future<void> Function() action,
  String done,
  VoidCallback refresh,
) async {
  try {
    await action();
    refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// A person link in a record dialog.
Widget _personLink(
  BuildContext context,
  String label,
  Object? id,
  Object? name,
) {
  if (id == null) return ListTile(dense: true, title: Text('$label: —'));
  return ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: const Icon(LucideIcons.userRound, size: 18),
    title: Text('${name ?? '—'}'),
    subtitle: Text(label),
    trailing: const Icon(LucideIcons.externalLink, size: 16),
    onTap: () {
      Navigator.of(context).pop();
      context.go('/admin/users/$id');
    },
  );
}

// ---------------------------------------------------------------------------
// Consultations
// ---------------------------------------------------------------------------

class AdminConsultationsScreen extends StatelessWidget {
  const AdminConsultationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RecordList(
      title: 'Consultations',
      subtitle: 'Every consultation and appointment',
      provider: consultationsPageProvider,
      searchHint: 'Patient, doctor, specialty or ID',
      statuses: const [
        ('in_progress', 'Live'),
        ('awaiting_payment', 'Awaiting payment'),
        ('scheduled', 'Scheduled'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
        ('expired', 'Expired'),
      ],
      onTapRow: (context, ref, r, refresh) => showDialog(
        context: context,
        builder: (ctx) {
          final active = !{
            'completed',
            'cancelled',
            'expired',
          }.contains(r['status']);
          return AlertDialog(
            title: Text('${r['specialty']} consultation'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      StatusChip.auto(r['status']),
                      StatusChip(humanize(r['mode'])),
                      if (r['paid'] == true)
                        const StatusChip('Paid', tone: Tone.good),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _personLink(
                    ctx,
                    'Patient',
                    r['patient_id'],
                    r['patient_name'],
                  ),
                  _personLink(ctx, 'Doctor', r['doctor_id'], r['doctor_name']),
                  const Divider(),
                  Text('Created ${stamp(parseTime(r['created_at']))}'),
                  Text('Started ${stamp(parseTime(r['started_at']))}'),
                  Text('Ended ${stamp(parseTime(r['ended_at']))}'),
                  Text('Fee ${kes(asNum(r['fee']))}'),
                  Text(
                    'Prescriptions ${r['prescriptions']} · family listeners ${r['family']}',
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    'ID ${r['id']}',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              if (active)
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AdminColors.critical,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _act(
                      context,
                      () => ref
                          .read(adminRepositoryProvider)
                          .cancelConsultation('${r['id']}'),
                      'Consultation cancelled; both sides notified',
                      refresh,
                    );
                  },
                  child: const Text('Cancel consultation'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
      columns: [
        AdminColumn(
          'Created',
          (r) => TwoLine(stamp(parseTime(r['created_at'])), shortId(r['id'])),
          width: 130,
        ),
        AdminColumn('Status', (r) => StatusChip.auto(r['status']), width: 150),
        AdminColumn(
          'Specialty',
          (r) => TwoLine('${r['specialty']}', humanize(r['mode'])),
          width: 160,
        ),
        AdminColumn(
          'Patient',
          (r) => CellText('${r['patient_name']}'),
          width: 170,
        ),
        AdminColumn(
          'Doctor',
          (r) => CellText('${r['doctor_name'] ?? '—'}'),
          width: 170,
        ),
        AdminColumn(
          'Fee',
          (r) => CellText(r['fee'] == null ? '—' : kes(asNum(r['fee']))),
          width: 100,
          numeric: true,
        ),
        AdminColumn(
          'Paid',
          (r) => r['paid'] == true
              ? const StatusChip('Paid', tone: Tone.good)
              : const CellText('—'),
          width: 90,
        ),
        AdminColumn(
          'Rx · family',
          (r) => CellText('${r['prescriptions']} · ${r['family']}'),
          width: 100,
          numeric: true,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

const _orderStatuses = [
  ('placed', 'Placed'),
  ('confirmed', 'Confirmed'),
  ('ready', 'Ready'),
  ('fulfilled', 'Fulfilled'),
  ('disputed', 'Disputed'),
  ('refunded', 'Refunded'),
];

class AdminOrdersScreen extends StatelessWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RecordList(
      title: 'Orders',
      subtitle: 'Medicine orders across all chemists',
      provider: ordersPageProvider,
      searchHint: 'Patient, chemist or ID',
      statuses: _orderStatuses,
      onTapRow: (context, ref, r, refresh) => showDialog(
        context: context,
        builder: (ctx) {
          String status = '${r['status']}';
          return StatefulBuilder(
            builder: (ctx, setState) => AlertDialog(
              title: Text('Order ${shortId(r['id']).toUpperCase()}'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        StatusChip.auto(r['status']),
                        StatusChip('Escrow ${humanize(r['escrow'])}'),
                        if (r['has_prescription'] == true)
                          const StatusChip('Prescription attached'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _personLink(
                      ctx,
                      'Patient',
                      r['patient_id'],
                      r['patient_name'],
                    ),
                    _personLink(
                      ctx,
                      'Chemist',
                      r['chemist_id'],
                      r['chemist_name'],
                    ),
                    const Divider(),
                    Text(
                      '${r['items']} items · ${kes(asNum(r['total']))} · ${humanize(r['fulfillment'])}',
                    ),
                    Text('Placed ${stamp(parseTime(r['created_at']))}'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(
                        labelText: 'Override status',
                        helperText:
                            'Refunded also refunds the payment; fulfilled releases escrow.',
                      ),
                      items: [
                        for (final (v, label) in _orderStatuses)
                          DropdownMenuItem(value: v, child: Text(label)),
                      ],
                      onChanged: (v) => setState(() => status = v ?? status),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                  onPressed: status == r['status']
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _act(
                            context,
                            () => ref
                                .read(adminRepositoryProvider)
                                .setOrderStatus('${r['id']}', status),
                            'Order set to ${humanize(status)}; patient notified',
                            refresh,
                          );
                        },
                  child: const Text('Save status'),
                ),
              ],
            ),
          );
        },
      ),
      columns: [
        AdminColumn(
          'Placed',
          (r) => TwoLine(stamp(parseTime(r['created_at'])), shortId(r['id'])),
          width: 130,
        ),
        AdminColumn('Status', (r) => StatusChip.auto(r['status']), width: 130),
        AdminColumn('Escrow', (r) => StatusChip.auto(r['escrow']), width: 120),
        AdminColumn(
          'Patient',
          (r) => CellText('${r['patient_name']}'),
          width: 170,
        ),
        AdminColumn(
          'Chemist',
          (r) => CellText('${r['chemist_name']}'),
          width: 170,
        ),
        AdminColumn(
          'Items',
          (r) => CellText('${r['items']}'),
          width: 70,
          numeric: true,
        ),
        AdminColumn(
          'Total',
          (r) => CellText(kes(asNum(r['total']))),
          width: 110,
          numeric: true,
        ),
        AdminColumn(
          'Rx',
          (r) => CellText(r['has_prescription'] == true ? 'Yes' : '—'),
          width: 60,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RecordList(
      title: 'Payments',
      subtitle: 'Every payment for consultations and medicines',
      provider: paymentsPageProvider,
      statuses: const [
        ('succeeded', 'Succeeded'),
        ('pending', 'Pending'),
        ('failed', 'Failed'),
        ('refunded', 'Refunded'),
      ],
      header: (page) {
        final rows = page?.rows ?? const <Map<String, dynamic>>[];
        final ok = rows.where((r) => r['status'] == 'succeeded');
        final sum = ok.fold<num>(0, (s, r) => s + asNum(r['amount']));
        final simulated = rows.where((r) => r['is_simulated'] == true).length;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ResponsiveGrid(
            minWidth: 200,
            children: [
              StatTile(
                label: 'Collected (this page)',
                value: kes(sum),
                icon: LucideIcons.wallet,
                caption: '${ok.length} successful payments',
              ),
              StatTile(
                label: 'Test payments',
                value: '$simulated of ${rows.length}',
                icon: LucideIcons.flaskConical,
                caption: 'M-Pesa is simulated until Daraja is connected',
              ),
            ],
          ),
        );
      },
      columns: [
        AdminColumn(
          'When',
          (r) => TwoLine(stamp(parseTime(r['created_at'])), shortId(r['id'])),
          width: 130,
        ),
        AdminColumn('Status', (r) => StatusChip.auto(r['status']), width: 130),
        AdminColumn('For', (r) => CellText(humanize(r['kind'])), width: 130),
        AdminColumn(
          'Payer',
          (r) => CellText('${r['payer_name'] ?? '—'}'),
          width: 180,
        ),
        AdminColumn(
          'Method',
          (r) => CellText(humanize(r['provider'])),
          width: 100,
        ),
        AdminColumn(
          'Amount',
          (r) => CellText(kes(asNum(r['amount']))),
          width: 110,
          numeric: true,
        ),
        AdminColumn(
          'Test',
          (r) => r['is_simulated'] == true
              ? const StatusChip('Test', tone: Tone.warning)
              : const CellText('Live'),
          width: 90,
        ),
        AdminColumn(
          'Reference',
          (r) => CellText(shortId(r['reference']), mono: true),
          width: 110,
        ),
      ],
    );
  }
}
