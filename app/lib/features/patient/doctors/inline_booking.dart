import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/design_kit.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';

const _days = 14;

/// A doctor's open slots for the next two weeks.
final profileSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlot>, String>((ref, doctorId) {
      final today = DateUtils.dateOnly(DateTime.now());
      return ref
          .watch(doctorDirectoryRepositoryProvider)
          .openSlots(doctorId, today, today.add(const Duration(days: _days - 1)));
    });

String bookingRoute(String doctorId, DateTime start) =>
    '/patient/book/$doctorId?at=${Uri.encodeQueryComponent(start.toUtc().toIso8601String())}';

/// "Earliest availability" — the soonest open time, big, with a button to
/// take it.
class EarliestAvailabilityCard extends StatelessWidget {
  const EarliestAvailabilityCard({super.key, required this.doctor});

  final PublicDoctor doctor;

  @override
  Widget build(BuildContext context) {
    final next = doctor.nextSlot;
    if (next == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.peachGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(next).toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    color: AppColors.peach,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${next.day}',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earliest availability',
                  style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
                ),
                Text(
                  '${DateFormat('EEEE').format(next)}, '
                  '${DateFormat('h:mm a').format(next)}',
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.peach,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: () =>
                context.push(bookingRoute(doctor.userId, next)),
            child: const Text('Take it'),
          ),
        ],
      ),
    );
  }
}

/// Pick a day, then a time, right on the profile.
class InlineBooking extends ConsumerStatefulWidget {
  const InlineBooking({super.key, required this.doctor});

  final PublicDoctor doctor;

  @override
  ConsumerState<InlineBooking> createState() => _InlineBookingState();
}

class _InlineBookingState extends ConsumerState<InlineBooking> {
  DateTime? _day;
  TimeSlot? _slot;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(profileSlotsProvider(widget.doctor.userId));
    return async.when(
      loading: () => const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (slots) {
        if (slots.isEmpty) {
          return Text(
            'No open times in the next two weeks.',
            style: text.bodyMedium,
          );
        }
        final byDay = <DateTime, List<TimeSlot>>{};
        for (final s in slots) {
          byDay.putIfAbsent(DateUtils.dateOnly(s.start), () => []).add(s);
        }
        final today = DateUtils.dateOnly(DateTime.now());
        final days = [
          for (var i = 0; i < _days; i++) today.add(Duration(days: i)),
        ];
        final day = _day ?? days.firstWhere(byDay.containsKey, orElse: () => today);
        final times = byDay[day] ?? const <TimeSlot>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DateScroller(
              days: days,
              selected: day,
              counts: {for (final e in byDay.entries) e.key: e.value.length},
              onSelected: (d) => setState(() {
                _day = d;
                _slot = null;
              }),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in times)
                  ChoiceChip(
                    label: Text(DateFormat('h:mm a').format(s.start)),
                    selected: _slot?.start == s.start,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _slot = s);
                    },
                  ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              child: _slot == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: FilledButton.icon(
                        icon: const Icon(LucideIcons.calendarCheck, size: 18),
                        label: Text(
                          'Book ${DateFormat('EEE d MMM').format(_slot!.start)}, '
                          '${DateFormat('h:mm a').format(_slot!.start)}',
                        ),
                        onPressed: () => context.push(
                          bookingRoute(widget.doctor.userId, _slot!.start),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
