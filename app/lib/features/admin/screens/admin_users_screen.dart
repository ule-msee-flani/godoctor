import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/admin_ui.dart';
import 'admin_activity_screen.dart' show activityColumns, describeDevice;

typedef UserQuery = ({String? search, String? role, String? status, int page});

const _pageSize = 50;

final usersPageProvider = FutureProvider.autoDispose
    .family<AdminRows, UserQuery>(
      (ref, q) => ref
          .watch(adminRepositoryProvider)
          .users(
            search: q.search,
            role: q.role,
            status: q.status,
            limit: _pageSize,
            offset: q.page * _pageSize,
          ),
    );

final userDetailProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>(
      (ref, id) => ref.watch(adminRepositoryProvider).userDetail(id),
    );

/// Every account on GoDoctor: search, filter by role/status, open one.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String? _search;
  String? _role;
  String? _status;
  int _page = 0;
  AdminRows? _last;

  UserQuery get _q =>
      (search: _search, role: _role, status: _status, page: _page);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(usersPageProvider(_q));
    final page = async.valueOrNull ?? _last;
    if (async.hasValue) _last = async.value;

    return AdminPage(
      title: 'Users',
      subtitle: page == null
          ? null
          : '${compactNumber(page.total)} matching accounts',
      actions: [
        AdminSearchField(
          hint: 'Name, email, phone or ID',
          onSubmitted: (v) => setState(() {
            _search = v.trim().isEmpty ? null : v.trim();
            _page = 0;
          }),
        ),
      ],
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          children: [
            FilterRow<String>(
              value: _role,
              allLabel: 'All roles',
              options: const [
                ('patient', 'Patients'),
                ('doctor', 'Doctors'),
                ('chemist', 'Chemists'),
                ('admin', 'Admins'),
              ],
              onChanged: (v) => setState(() {
                _role = v;
                _page = 0;
              }),
            ),
            FilterRow<String>(
              value: _status,
              allLabel: 'Any status',
              options: const [('active', 'Active'), ('suspended', 'Suspended')],
              onChanged: (v) => setState(() {
                _status = v;
                _page = 0;
              }),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (async.hasError && page == null)
          ErrorView(
            message: friendlyError(async.error!),
            onRetry: () => ref.invalidate(usersPageProvider(_q)),
          )
        else
          AdminTable(
            loading: async.isLoading,
            rows: page?.rows ?? const [],
            total: page?.total,
            page: _page,
            pageSize: _pageSize,
            onPage: (p) => setState(() => _page = p),
            onTapRow: (r) => context.go('/admin/users/${r['id']}'),
            emptyMessage: 'No users match.',
            columns: [
              AdminColumn(
                'User',
                (r) => Row(
                  children: [
                    UserAvatar(
                      name: '${r['name']}',
                      path: r['avatar_url'] as String?,
                      radius: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TwoLine(
                        '${r['name']}',
                        (r['email'] as String?) ?? (r['phone'] as String?),
                      ),
                    ),
                  ],
                ),
                width: 260,
              ),
              AdminColumn(
                'Role',
                (r) => CellText(humanize(r['role'])),
                width: 100,
              ),
              AdminColumn(
                'Status',
                (r) => StatusChip.auto(r['status']),
                width: 120,
              ),
              AdminColumn(
                'Verified',
                (r) => r['verified'] == null
                    ? const CellText('—')
                    : StatusChip(
                        r['verified'] == true ? 'Verified' : 'Pending',
                        tone: r['verified'] == true ? Tone.good : Tone.warning,
                      ),
                width: 110,
              ),
              AdminColumn(
                'Joined',
                (r) => CellText(stamp(parseTime(r['created_at']))),
              ),
              AdminColumn(
                'Last sign-in',
                (r) => CellText(ago(parseTime(r['last_sign_in_at']))),
              ),
              AdminColumn(
                'Last seen',
                (r) => CellText(ago(parseTime(r['last_seen_at']))),
              ),
            ],
          ),
      ],
    );
  }
}

/// One user: identity, status actions, stats, profile, devices, recent
/// consultations/orders and their latest database activity.
class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    String name,
    bool suspend,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspend ? 'Suspend $name?' : 'Reactivate $name?'),
        content: Text(
          suspend
              ? 'They are signed out everywhere and cannot sign in until you reactivate them.'
              : 'They will be able to sign in and use GoDoctor again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: suspend
                ? FilledButton.styleFrom(backgroundColor: AdminColors.critical)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspend ? 'Suspend' : 'Reactivate'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _run(
      context,
      ref,
      () => ref
          .read(adminRepositoryProvider)
          .setUserStatus(userId, suspend ? 'suspended' : 'active'),
      suspend ? '$name suspended' : '$name reactivated',
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String done,
  ) async {
    try {
      await action();
      ref.invalidate(userDetailProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
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
    final async = ref.watch(userDetailProvider(userId));
    return async.when(
      loading: () =>
          const ColoredBox(color: AdminColors.page, child: LoadingView()),
      error: (e, _) => ErrorView(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(userDetailProvider(userId)),
      ),
      data: (d) {
        if (d == null) return const ErrorView(message: 'User not found');
        final user = (d['user'] as Map).cast<String, dynamic>();
        final auth = (d['auth'] as Map?)?.cast<String, dynamic>() ?? const {};
        final profile = (d['profile'] as Map?)?.cast<String, dynamic>();
        final stats = (d['stats'] as Map).cast<String, dynamic>();
        final name = '${user['name']}';
        final role = '${user['role']}';
        final suspended = user['status'] == 'suspended';
        final verified = switch (role) {
          'doctor' => profile?['license_verified'] == true,
          'chemist' => profile?['verified'] == true,
          _ => null,
        };
        List<Map<String, dynamic>> list(String k) =>
            ((d[k] as List?) ?? const []).cast<Map<String, dynamic>>();

        final theme = Theme.of(context).textTheme;
        return AdminPage(
          title: name,
          subtitle:
              '${humanize(role)} · ${user['email'] ?? user['phone'] ?? ''}',
          onRefresh: () async => ref.invalidate(userDetailProvider(userId)),
          actions: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => context.go('/admin/users'),
              icon: const Icon(LucideIcons.chevronLeft, size: 16),
              label: const Text('All users'),
            ),
            if (verified != null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: () => _run(
                  context,
                  ref,
                  () => role == 'doctor'
                      ? ref
                            .read(profileRepositoryProvider)
                            .adminSetDoctorVerified(userId, !verified)
                      : ref
                            .read(profileRepositoryProvider)
                            .adminSetChemistVerified(userId, !verified),
                  verified ? 'Verification removed' : '$name verified',
                ),
                icon: Icon(
                  verified ? LucideIcons.shieldOff : LucideIcons.shieldCheck,
                  size: 16,
                ),
                label: Text(verified ? 'Remove verification' : 'Verify'),
              ),
            if (role != 'admin')
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: suspended ? null : AdminColors.critical,
                ),
                onPressed: () => _setStatus(context, ref, name, !suspended),
                icon: Icon(
                  suspended ? LucideIcons.userCheck : LucideIcons.ban,
                  size: 16,
                ),
                label: Text(suspended ? 'Reactivate' : 'Suspend'),
              ),
          ],
          children: [
            AdminCard(
              child: Wrap(
                spacing: 28,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  UserAvatar(
                    name: name,
                    path: user['avatar_url'] as String?,
                    radius: 32,
                  ),
                  _Fact('Status', StatusChip.auto(user['status'])),
                  if (verified != null)
                    _Fact(
                      'Verification',
                      StatusChip(
                        verified ? 'Verified' : 'Pending',
                        tone: verified ? Tone.good : Tone.warning,
                      ),
                    ),
                  _Fact('Joined', Text(stamp(parseTime(user['created_at'])))),
                  _Fact(
                    'Last sign-in',
                    Text(ago(parseTime(auth['last_sign_in_at']))),
                  ),
                  _Fact(
                    'Last seen',
                    Text(ago(parseTime(user['last_seen_at']))),
                  ),
                  _Fact(
                    'Email confirmed',
                    Text(auth['email_confirmed_at'] == null ? 'No' : 'Yes'),
                  ),
                  _Fact(
                    'User ID',
                    SelectableText(
                      '${user['id']}',
                      style: theme.bodySmall?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ResponsiveGrid(
              minWidth: 170,
              children: [
                for (final (label, key, money) in const [
                  (
                    'Consultations (patient)',
                    'consultations_as_patient',
                    false,
                  ),
                  ('Consultations (doctor)', 'consultations_as_doctor', false),
                  ('Orders placed', 'orders_placed', false),
                  ('Orders received', 'orders_received', false),
                  ('Total spent', 'spent', true),
                  ('Prescriptions issued', 'prescriptions_issued', false),
                  ('Prescriptions received', 'prescriptions_received', false),
                  ('Family links', 'family_links', false),
                  ('Support tickets', 'tickets', false),
                  ('Database writes (30 d)', 'writes_30d', false),
                ])
                  if (asNum(stats[key]) > 0 || key == 'writes_30d')
                    StatTile(
                      label: label,
                      value: money
                          ? kes(asNum(stats[key]))
                          : compactNumber(asNum(stats[key])),
                      icon: LucideIcons.chartLine,
                    ),
              ],
            ),
            const SizedBox(height: 14),
            ResponsiveGrid(
              minWidth: 420,
              children: [
                AdminCard(
                  title: 'Profile',
                  child: profile == null
                      ? Text('No profile row.', style: theme.bodySmall)
                      : _KeyValues(profile),
                ),
                AdminCard(
                  title: 'Signed-in devices',
                  subtitle: '${list('sessions').length} active sessions',
                  child: list('sessions').isEmpty
                      ? Text('Not signed in anywhere.', style: theme.bodySmall)
                      : Column(
                          children: [
                            for (final s in list('sessions'))
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(
                                  LucideIcons.monitorSmartphone,
                                  size: 18,
                                ),
                                title: Text(
                                  describeDevice(s['user_agent'] as String?),
                                ),
                                subtitle: Text(
                                  '${s['ip'] ?? 'unknown IP'} · signed in ${stamp(parseTime(s['created_at']))}',
                                ),
                                trailing: Text(
                                  ago(parseTime(s['last_active'])),
                                  style: theme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ResponsiveGrid(
              minWidth: 420,
              children: [
                AdminCard(
                  title: 'Recent consultations',
                  child: _MiniList(
                    rows: list('consultations'),
                    empty: 'None',
                    line: (r) =>
                        '${r['specialty_requested']} · with ${r['other'] ?? '—'}',
                    status: (r) => r['status'],
                    time: (r) => parseTime(r['created_at']),
                  ),
                ),
                AdminCard(
                  title: 'Recent orders',
                  child: _MiniList(
                    rows: list('orders'),
                    empty: 'None',
                    line: (r) =>
                        '${kes(asNum(r['total_amount']))} · ${r['other'] ?? '—'}',
                    status: (r) => r['status'],
                    time: (r) => parseTime(r['created_at']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Their latest database activity', style: theme.titleSmall),
            const SizedBox(height: 8),
            AdminTable(
              rows: [
                for (final a in list('activity'))
                  {...a, 'actor_name': name, 'actor_role': role},
              ],
              columns: activityColumns,
              emptyMessage: 'No writes in the last 30 days.',
            ),
          ],
        );
      },
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: theme.bodySmall),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(
          style: theme.bodyMedium?.copyWith(color: AppColors.ink),
          child: value,
        ),
      ],
    );
  }
}

/// Profile columns as label/value rows (internal ids and timestamps hidden).
class _KeyValues extends StatelessWidget {
  const _KeyValues(this.map);

  final Map<String, dynamic> map;

  static const _hidden = {'user_id', 'created_at', 'updated_at', 'avatar_url'};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final entries = map.entries.where((e) => !_hidden.contains(e.key)).toList();
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: Text(humanize(e.key), style: theme.bodySmall),
                ),
                Expanded(
                  child: SelectableText(switch (e.value) {
                    null => '—',
                    final List l => l.isEmpty ? '—' : l.join(', '),
                    final v => '$v',
                  }, style: theme.bodyMedium?.copyWith(color: AppColors.ink)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MiniList extends StatelessWidget {
  const _MiniList({
    required this.rows,
    required this.empty,
    required this.line,
    required this.status,
    required this.time,
  });

  final List<Map<String, dynamic>> rows;
  final String empty;
  final String Function(Map<String, dynamic>) line;
  final Object? Function(Map<String, dynamic>) status;
  final DateTime? Function(Map<String, dynamic>) time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (rows.isEmpty) return Text(empty, style: theme.bodySmall);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: TwoLine(line(r), stamp(time(r)))),
                StatusChip.auto(status(r)),
              ],
            ),
          ),
      ],
    );
  }
}
