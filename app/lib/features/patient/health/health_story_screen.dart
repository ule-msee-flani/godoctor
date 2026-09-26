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
        route: p.items.isEmpty ? null : '/patient/prescription/${p.id}/order',
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

/// Health: my key health facts, the medicines I'm taking, and my health
/// story -- every consultation, prescription and order on one timeline.
class HealthStoryScreen extends ConsumerStatefulWidget {
  const HealthStoryScreen({super.key});

  @override
  ConsumerState<HealthStoryScreen> createState() => _HealthStoryScreenState();
}

class _HealthStoryScreenState extends ConsumerState<HealthStoryScreen> {
  HealthFilter _filter = HealthFilter.all;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final story = ref.watch(_healthStoryProvider);
    final patient = ref.watch(currentPatientProfileProvider).valueOrNull;

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
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_healthStoryProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HealthFacts(
              allergies: patient?.allergies,
              bloodGroup: patient?.bloodGroup,
              conditions: patient?.chronicConditions,
              onEdit: () => context.push('/patient/profile/health'),
            ),
            const SizedBox(height: 20),
            const MedicinesTakingSection(),
            const SizedBox(height: 10),
            Text('Your health story', style: theme.titleMedium),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in HealthFilter.values) ...[
                    ChoiceChip(
                      label: Text(switch (f) {
                        HealthFilter.all => 'All',
                        HealthFilter.consultations => 'Consultations',
                        HealthFilter.prescriptions => 'Prescriptions',
                        HealthFilter.orders => 'Orders',
                      }),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            story.when(
              loading: () => const SizedBox(
                height: 300,
                child: SkeletonList(itemCount: 4, padding: EdgeInsets.zero),
              ),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(_healthStoryProvider),
              ),
              data: (all) {
                final list = _filter == HealthFilter.all
                    ? all
                    : all.where((e) => e.kind == _filter).toList();
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      _filter == HealthFilter.all
                          ? 'Your consultations, prescriptions and orders will appear here.'
                          : 'Nothing here yet.',
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      _TimelineTile(
                        event: list[i],
                        first: i == 0,
                        last: i == list.length - 1,
                        showYear:
                            i == 0 || list[i - 1].at.year != list[i].at.year,
                      ),
                  ],
                );
              },
            ),
          ],
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
    required this.showYear,
  });

  final HealthEvent event;
  final bool first;
  final bool last;
  final bool showYear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final e = event;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showYear && e.at.year != now.year)
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 6, top: 4),
            child: Text('${e.at.year}', style: theme.labelLarge),
          ),
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
