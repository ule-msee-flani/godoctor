import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/models/prescription.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medications/medicines_taking_section.dart';
import '../../../core/widgets/motion.dart';
import '../../../services/live_updates.dart';
import '../screens/order_history_screen.dart';
import '../screens/prescriptions_screen.dart';
import '../visits/visit_widgets.dart';

enum HealthFilter { all, consultations, prescriptions, orders }

/// One moment in the patient's health story.
class HealthEvent {
  const HealthEvent({
    required this.kind,
    required this.at,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.route,
    this.status,
  });

  final HealthFilter kind;
  final DateTime at;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? route;
  final String? status;
}

/// Consultations, prescriptions and orders merged into one timeline,
/// newest first. Pure, so it can be tested.
List<HealthEvent> buildHealthStory({
  required List<Consultation> consultations,
  required List<Prescription> prescriptions,
  required List<model.Order> orders,
}) {
  final events = <HealthEvent>[
    for (final c in consultations)
      if (c.status != ConsultationStatus.cancelled &&
          c.status != ConsultationStatus.unmatched)
        HealthEvent(
          kind: HealthFilter.consultations,
          at: (c.scheduledFor ?? c.startedAt ?? c.createdAt).toLocal(),
          title: '${c.specialtyRequested} consultation',
          subtitle: c.symptomSummary,
          icon: c.isScheduled
              ? LucideIcons.calendarClock
              : LucideIcons.stethoscope,
          status: switch (c.status) {
            ConsultationStatus.completed => null,
            ConsultationStatus.inProgress => 'In progress',
            ConsultationStatus.awaitingPayment => 'Awaiting payment',
            ConsultationStatus.scheduled => 'Upcoming',
            _ => 'Waiting',
          },
          route: c.status == ConsultationStatus.completed
              ? '/patient/visit/${c.id}'
              : c.isScheduled
              ? '/patient/appointment/${c.id}'
              : c.status == ConsultationStatus.awaitingPayment
              ? '/patient/consult/${c.id}/pay'
              : '/patient/waiting/${c.id}',
        ),
    for (final p in prescriptions)
      HealthEvent(
        kind: HealthFilter.prescriptions,
        at: p.issuedAt.toLocal(),
        title: p.source == PrescriptionSource.externalUpload
            ? 'Uploaded prescription'
            : 'Prescription · ${p.items.length} '
                  '${p.items.length == 1 ? 'medicine' : 'medicines'}',
        subtitle: p.items.isEmpty
            ? 'Photo of a prescription'
            : p.items.map((i) => i.displayName).join(', '),
        icon: LucideIcons.fileText,
        route: '/patient/prescription/${p.id}',
      ),
    for (final o in orders)
      HealthEvent(
        kind: HealthFilter.orders,
        at: o.createdAt.toLocal(),
        title: 'Medicine order · ${formatKes(o.totalAmount)}',
        subtitle: [
          if (o.chemistName != null) o.chemistName!,
          o.items.map((i) => i.drugName ?? 'Medicine').join(', '),
        ].where((s) => s.isNotEmpty).join(' · '),
        icon: LucideIcons.shoppingBag,
        status: switch (o.status) {
          OrderStatus.fulfilled => null,
          OrderStatus.placed => 'Placed',
          OrderStatus.confirmed => 'Being prepared',
          OrderStatus.ready => 'Ready',
          OrderStatus.disputed => 'Disputed',
          OrderStatus.refunded => 'Refunded',
        },
        route: '/patient/order/${o.id}',
      ),
  ]..sort((a, b) => b.at.compareTo(a.at));
  return events;
}

final _healthStoryProvider = FutureProvider.autoDispose<List<HealthEvent>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  ref.watch(liveTick(LiveTable.orders));
  ref.watch(liveTick(LiveTable.prescriptions));
  ref.watch(liveTick(LiveTable.consultations));
  if (userId == null) return const [];
  final results = await Future.wait([
    ref.watch(consultationRepositoryProvider).fetchHistoryForPatient(userId),
    ref.watch(prescriptionRepositoryProvider).fetchForPatient(userId),
    ref.watch(orderRepositoryProvider).fetchForPatient(userId),
  ]);
  return buildHealthStory(
    consultations: results[0] as List<Consultation>,
    prescriptions: results[1] as List<Prescription>,
    orders: results[2] as List<model.Order>,
  );
});

/// The Health tab's sections, in order. `/patient/health?tab=visits` opens
/// straight on one.
enum HealthTab { overview, visits, prescriptions, orders }

/// Health: my key health facts and the medicines I'm taking, then my visits,
/// prescriptions and orders -- each in its own section, grouped by month.
class HealthStoryScreen extends ConsumerStatefulWidget {
  const HealthStoryScreen({super.key, this.initialTab});

  /// A [HealthTab] name, e.g. "visits".
  final String? initialTab;

  @override
  ConsumerState<HealthStoryScreen> createState() => _HealthStoryScreenState();
}

class _HealthStoryScreenState extends ConsumerState<HealthStoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: HealthTab.values.length,
    vsync: this,
    initialIndex: _indexOf(widget.initialTab) ?? 0,
  );

  static int? _indexOf(String? name) {
    for (final t in HealthTab.values) {
      if (t.name == name) return t.index;
    }
    return null;
  }

  @override
  void didUpdateWidget(HealthStoryScreen old) {
    super.didUpdateWidget(old);
    final i = _indexOf(widget.initialTab);
    if (widget.initialTab != old.initialTab && i != null) _tabs.animateTo(i);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        actions: [
          IconButton(
            tooltip: 'Upload a prescription',
            icon: const Icon(LucideIcons.upload),
            onPressed: () => context.push('/patient/prescriptions/upload'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Visits'),
            Tab(text: 'Prescriptions'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _Overview(onOpen: (tab) => _tabs.animateTo(tab.index)),
          const VisitsList(),
          const PrescriptionsList(),
          const OrderHistoryList(),
        ],
      ),
    );
  }
}

/// Facts, shortcuts into each section, medicines, and the whole story on
/// one timeline grouped by month.
class _Overview extends ConsumerWidget {
  const _Overview({required this.onOpen});

  final ValueChanged<HealthTab> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final story = ref.watch(_healthStoryProvider);
    final patient = ref.watch(currentPatientProfileProvider).valueOrNull;
    final events = story.valueOrNull ?? const <HealthEvent>[];
    int count(HealthFilter k) => events.where((e) => e.kind == k).length;

    return LiveRefresh(
      onRefresh: () => ref.refresh(_healthStoryProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HealthFacts(
            allergies: patient?.allergies,
            bloodGroup: patient?.bloodGroup,
            conditions: patient?.chronicConditions,
            onEdit: () => context.push('/patient/profile/health'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Shortcut(
                icon: LucideIcons.stethoscope,
                count: count(HealthFilter.consultations),
                noun: ('visit', 'visits'),
                color: AppColors.primary,
                onTap: () => onOpen(HealthTab.visits),
              ),
              const SizedBox(width: 10),
              _Shortcut(
                icon: LucideIcons.fileText,
                count: count(HealthFilter.prescriptions),
                noun: ('prescription', 'prescriptions'),
                color: AppColors.accentTeal,
                onTap: () => onOpen(HealthTab.prescriptions),
              ),
              const SizedBox(width: 10),
              _Shortcut(
                icon: LucideIcons.shoppingBag,
                count: count(HealthFilter.orders),
                noun: ('order', 'orders'),
                color: AppColors.warning,
                onTap: () => onOpen(HealthTab.orders),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const MedicinesTakingSection(),
          const SizedBox(height: 10),
          Text('Your health story', style: theme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Everything, newest first.',
            style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          story.when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const SizedBox(
              height: 300,
              child: SkeletonList(itemCount: 4, padding: EdgeInsets.zero),
            ),
            error: (e, _) => ErrorView(
              message: friendlyError(e),
              onRetry: () => ref.invalidate(_healthStoryProvider),
            ),
            data: (all) {
              if (all.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'Your visits, prescriptions and orders will appear here.',
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium,
                  ),
                );
              }
              var i = 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, group) in groupByMonth(
                    all,
                    (e) => e.at,
                  )) ...[
                    MonthHeader(label),
                    for (var j = 0; j < group.length; j++)
                      FadeSlideIn(
                        index: i++,
                        child: _TimelineTile(
                          event: group[j],
                          first: j == 0,
                          last: j == group.length - 1,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// "3 visits" — a tap opens that section.
class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.count,
    required this.noun,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final (String, String) noun;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Pressable(
        child: Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 8),
                  Text(
                    '$count',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    count == 1 ? noun.$1 : noun.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HealthFacts extends StatelessWidget {
  const _HealthFacts({
    required this.allergies,
    required this.bloodGroup,
    required this.conditions,
    required this.onEdit,
  });

  final String? allergies;
  final String? bloodGroup;
  final String? conditions;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    String? v(String? s) => (s ?? '').trim().isEmpty ? null : s!.trim();
    final a = v(allergies), b = v(bloodGroup), c = v(conditions);

    Widget fact(String label, String? value, {bool danger = false}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value ?? 'Not added',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.titleSmall?.copyWith(
              color: value == null
                  ? AppColors.inkFaint
                  : danger
                  ? AppColors.danger
                  : AppColors.ink,
            ),
          ),
        ],
      ),
    );

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact('Allergies', a, danger: a != null),
              const SizedBox(width: 12),
              fact('Blood group', b),
              const SizedBox(width: 12),
              fact('Conditions', c),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.first,
    required this.last,
  });

  final HealthEvent event;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final e = event;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 2,
                      height: 14,
                      color: first ? Colors.transparent : AppColors.border,
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.white,
                        border: Border.all(color: AppColors.borderStrong),
                      ),
                      child: Icon(e.icon, size: 15, color: AppColors.ink),
                    ),
                    Expanded(
                      child: Container(
                        width: 2,
                        color: last ? Colors.transparent : AppColors.border,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: e.route == null
                        ? null
                        : () => context.push(e.route!),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.titleSmall,
                                ),
                              ),
                              Text(
                                isSameDay(e.at, now)
                                    ? formatTime(e.at)
                                    : formatDayShort(e.at),
                                style: theme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall,
                          ),
                          if (e.status != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                e.status!,
                                style: theme.labelSmall?.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
