import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/consultation.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/medication.dart';
import '../../../data/models/order.dart' as model;
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../chat/chat_providers.dart';
import '../../medications/medication_providers.dart';
import '../../../core/widgets/motion.dart';

/// My on-demand consultation that's still under way, live.
final activeConsultationProvider = StreamProvider.autoDispose<Consultation?>((
  ref,
) {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return Stream.value(null);
  return ref.watch(consultationRepositoryProvider).watchActiveForPatient(id);
});

/// My medicine orders a chemist is still working on.
final ordersInProgressProvider = FutureProvider.autoDispose<List<model.Order>>((
  ref,
) async {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return const [];
  final orders = await ref.watch(orderRepositoryProvider).fetchForPatient(id);
  return [
    for (final o in orders)
      if (o.status == OrderStatus.placed ||
          o.status == OrderStatus.confirmed ||
          o.status == OrderStatus.ready)
        o,
  ];
});

/// What the home card should be about right now, most urgent first.
sealed class HomeFocus {
  const HomeFocus();
}

class FocusConsultation extends HomeFocus {
  const FocusConsultation(this.consultation);
  final Consultation consultation;
}

class FocusAppointment extends HomeFocus {
  const FocusAppointment(this.consultation);
  final Consultation consultation;
}

class FocusDoseDue extends HomeFocus {
  const FocusDoseDue(this.schedule, this.dose);
  final MedicationSchedule schedule;
  final DoseLog dose;
}

class FocusChat extends HomeFocus {
  const FocusChat(this.thread);
  final ChatThread thread;
}

class FocusOrder extends HomeFocus {
  const FocusOrder(this.order);
  final model.Order order;
}

class FocusNextDose extends HomeFocus {
  const FocusNextDose(this.schedule, this.at);
  final MedicationSchedule schedule;
  final DateTime at;
}

class FocusFeeling extends HomeFocus {
  const FocusFeeling();
}

/// Picks the card. Pure, so the order of priorities is tested.
HomeFocus pickHomeFocus({
  required DateTime now,
  Consultation? active,
  List<Consultation> upcoming = const [],
  List<MedicationSchedule> schedules = const [],
  List<ChatThread> chats = const [],
  List<model.Order> orders = const [],
}) {
  if (active != null) return FocusConsultation(active);
  final live = upcoming.where((c) => c.canStartNow).firstOrNull;
  if (live != null) return FocusAppointment(live);
  for (final s in schedules) {
    final d = s.pendingDose;
    if (d != null) return FocusDoseDue(s, d);
  }
  final unread = chats.where((c) => c.isOpen && c.unread > 0).firstOrNull;
  if (unread != null) return FocusChat(unread);
  if (orders.isNotEmpty) return FocusOrder(orders.first);
  // Next dose within the next 3 hours.
  DateTime? soonest;
  MedicationSchedule? soonestFor;
  for (final s in schedules) {
    final n = s.nextDose(now);
    if (n != null &&
        n.difference(now) < const Duration(hours: 3) &&
        (soonest == null || n.isBefore(soonest))) {
      soonest = n;
      soonestFor = s;
    }
  }
  if (soonest != null) return FocusNextDose(soonestFor!, soonest);
  final next = upcoming.firstOrNull;
  if (next != null) return FocusAppointment(next);
  return const FocusFeeling();
}

/// The top-of-home card that changes with what's going on: a consultation
/// in progress, an appointment starting, a dose due, a reply from the
/// doctor, an order on its way... or simply "How are you feeling today?".
class SmartHomeCard extends ConsumerWidget {
  const SmartHomeCard({super.key, required this.onFeeling});

  /// Start a consultation about [symptom] in [specialty].
  final void Function(String specialty, String symptom) onFeeling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final focus = pickHomeFocus(
      now: DateTime.now(),
      active: ref.watch(activeConsultationProvider).valueOrNull,
      upcoming: ref.watch(upcomingAppointmentsProvider).valueOrNull ?? const [],
      schedules: ref.watch(activeSchedulesProvider).valueOrNull ?? const [],
      chats: ref.watch(myChatsProvider).valueOrNull ?? const [],
      orders: ref.watch(ordersInProgressProvider).valueOrNull ?? const [],
    );

    final Widget card = switch (focus) {
      FocusConsultation(:final consultation) => _ConsultationCard(
        consultation: consultation,
      ),
      FocusAppointment(:final consultation) => _Card(
        icon: LucideIcons.calendarClock,
        eyebrow: consultation.canStartNow
            ? 'Your appointment is ready'
            : 'Next appointment',
        title: consultation.scheduledFor == null
            ? consultation.specialtyRequested
            : formatRelativeSlot(consultation.scheduledFor!.toLocal()),
        body: consultation.specialtyRequested,
        strong: consultation.canStartNow,
        action: consultation.canStartNow ? 'Join' : null,
        onTap: () => context.push('/patient/appointment/${consultation.id}'),
      ),
      FocusDoseDue(:final schedule, :final dose) => _DoseDueCard(
        schedule: schedule,
        dose: dose,
      ),
      FocusChat(:final thread) => _Card(
        icon: LucideIcons.messageCircle,
        eyebrow: 'New message',
        title: thread.otherName,
        body: thread.lastBody ?? thread.symptoms,
        leading: UserAvatar(
          name: thread.otherName,
          path: thread.otherAvatar,
          radius: 22,
        ),
        action: 'Reply',
        onTap: () => context.push('/patient/chat/${thread.consultationId}'),
      ),
      FocusOrder(:final order) => _OrderCard(order: order),
      FocusNextDose(:final schedule, :final at) => _Card(
        icon: LucideIcons.alarmClock,
        eyebrow: 'Next dose',
        title: '${schedule.drugName} at ${formatTime(at)}',
        body: [
          if (schedule.dosage?.isNotEmpty ?? false) schedule.dosage!,
          'Day ${schedule.dayOfCourse(DateTime.now())} of ${schedule.totalDays}',
        ].join(' · '),
        onTap: () => context.go('/patient/health'),
      ),
      FocusFeeling() => _FeelingCard(onPick: onFeeling),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(focus.runtimeType), child: card),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.onTap,
    this.action,
    this.leading,
    this.strong = false,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String body;
  final VoidCallback onTap;
  final String? action;
  final Widget? leading;

  /// Blue card for "act now" moments.
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final fg = strong ? Colors.white : AppColors.ink;
    final soft = strong ? Colors.white70 : AppColors.inkSoft;
    final card = Material(
      color: strong ? AppColors.primary : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: strong
            ? BorderSide.none
            : const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              leading ?? Icon(icon, size: 24, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: theme.bodySmall?.copyWith(color: soft),
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleMedium?.copyWith(color: fg),
                    ),
                    Text(
                      body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodySmall?.copyWith(color: soft),
                    ),
                  ],
                ),
              ),
              if (action != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: strong ? Colors.white : AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    action!,
                    style: theme.labelLarge?.copyWith(
                      color: strong ? AppColors.primary : Colors.white,
                    ),
                  ),
                )
              else
                Icon(LucideIcons.chevronRight, size: 20, color: soft),
            ],
          ),
        ),
      ),
    );
    return Pressable(child: card);
  }
}

class _ConsultationCard extends StatelessWidget {
  const _ConsultationCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final c = consultation;
    return switch (c.status) {
      ConsultationStatus.inProgress => _Card(
        icon: LucideIcons.video,
        eyebrow: 'Consultation in progress',
        title: c.doctorJoinedAt == null
            ? 'Your doctor is joining'
            : 'Your doctor is on the call',
        body: c.specialtyRequested,
        strong: true,
        action: 'Join',
        onTap: () => context.push('/patient/call/${c.id}'),
      ),
      ConsultationStatus.awaitingPayment => _Card(
        icon: LucideIcons.wallet,
        eyebrow: 'Finish paying to start',
        title: c.paymentDueAt == null
            ? 'Your doctor is reserved'
            : 'Doctor reserved until ${formatTime(c.paymentDueAt!.toLocal())}',
        body: [
          c.specialtyRequested,
          if (c.feeAmount != null) formatKes(c.feeAmount),
        ].join(' · '),
        strong: true,
        action: 'Pay',
        onTap: () => context.push('/patient/consult/${c.id}/pay'),
      ),
      _ => _Card(
        icon: LucideIcons.hourglass,
        eyebrow: 'Finding your doctor',
        title: c.specialtyRequested,
        body: c.symptomSummary,
        onTap: () => context.push('/patient/waiting/${c.id}'),
      ),
    };
  }
}

class _DoseDueCard extends ConsumerStatefulWidget {
  const _DoseDueCard({required this.schedule, required this.dose});

  final MedicationSchedule schedule;
  final DoseLog dose;

  @override
  ConsumerState<_DoseDueCard> createState() => _DoseDueCardState();
}

class _DoseDueCardState extends ConsumerState<_DoseDueCard> {
  bool _busy = false;

  Future<void> _answer(bool taken) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(medicationRepositoryProvider)
          .markDose(widget.dose.id, taken: taken);
      if (taken) HapticFeedback.lightImpact();
      ref.invalidate(activeSchedulesProvider);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final s = widget.schedule;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alarmClock,
                size: 22,
                color: AppColors.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Time for your medicine · ${formatTime(widget.dose.dueAt)}',
                      style: theme.bodySmall,
                    ),
                    Text(s.drugName, style: theme.titleMedium),
                    if (s.dosage?.isNotEmpty ?? false)
                      Text(s.dosage!, style: theme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : () => _answer(false),
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _busy ? null : () => _answer(true),
                icon: const Icon(LucideIcons.check, size: 18),
                label: const Text('Taken'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final model.Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final step = switch (order.status) {
      OrderStatus.placed => 0,
      OrderStatus.confirmed => 1,
      _ => 2,
    };
    const labels = ['Placed', 'Being prepared', 'Ready'];
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/patient/order/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.shoppingBag,
                    size: 22,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your medicine order', style: theme.bodySmall),
                        Text(
                          step == 2 ? 'Ready to collect' : labels[step],
                          style: theme.titleMedium,
                        ),
                        if (order.chemistName != null)
                          Text(order.chemistName!, style: theme.bodySmall),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= step
                              ? AppColors.primary
                              : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingCard extends StatelessWidget {
  const _FeelingCard({required this.onPick});

  final void Function(String specialty, String symptom) onPick;

  static const _options = [
    ('Headache', 'General Practice'),
    ('Fever', 'General Practice'),
    ('Cough or cold', 'General Practice'),
    ('Stomach upset', 'General Practice'),
    ('Skin problem', 'Dermatology'),
    ('My child is unwell', 'Pediatrics'),
    ('Feeling low', 'Psychiatry/Mental Health'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How are you feeling today?', style: theme.titleMedium),
          const SizedBox(height: 2),
          Text('Tap one to talk to a doctor about it.', style: theme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, specialty) in _options)
                ActionChip(
                  label: Text(label),
                  onPressed: () => onPick(specialty, label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
