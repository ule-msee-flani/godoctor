import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

final _availabilityProvider =
    FutureProvider.autoDispose<List<AvailabilityWindow>>(
      (ref) => ref.watch(doctorScheduleRepositoryProvider).fetchAvailability(),
    );

final _timeOffProvider = FutureProvider.autoDispose<List<TimeOff>>(
  (ref) => ref.watch(doctorScheduleRepositoryProvider).fetchTimeOff(),
);

int _minutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// A doctor publishes when patients can book them: weekly hours plus days off.
/// Patients see the resulting open slots (Kenya time) in the directory.
class DoctorScheduleScreen extends ConsumerWidget {
  const DoctorScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(_availabilityProvider);
    final timeOff = ref.watch(_timeOffProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My schedule')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.info,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hours are in Kenya time (EAT). Patients can book any free slot inside these '
                        'hours, from 30 minutes ahead up to two weeks out.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Weekly hours',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _addHours(
                      context,
                      ref,
                      availability.valueOrNull ?? const [],
                    ),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Add hours'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              availability.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingView(),
                ),
                error: (e, _) => ErrorView(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(_availabilityProvider),
                ),
                data: (windows) => Column(
                  children: [
                    for (var day = 1; day <= 7; day++)
                      _DayRow(
                        day: day,
                        windows: windows
                            .where((w) => w.weekday == day)
                            .toList(),
                        onDelete: (w) async {
                          await ref
                              .read(doctorScheduleRepositoryProvider)
                              .deleteWindow(w.id!);
                          ref.invalidate(_availabilityProvider);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Time off',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => _addTimeOff(context, ref),
                    icon: const Icon(LucideIcons.calendarX, size: 18),
                    label: const Text('Add time off'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Slots on these days are hidden from patients. Existing bookings are not cancelled automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              timeOff.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: LoadingView(),
                ),
                error: (e, _) => Text(friendlyError(e)),
                data: (list) {
                  if (list.isEmpty) {
                    return Text(
                      'No time off planned.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  }
                  return Column(
                    children: [
                      for (final t in list)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(
                              LucideIcons.calendarX,
                              color: AppColors.warning,
                            ),
                            title: Text(
                              '${formatDayShort(t.startsAt)}  →  ${formatDayShort(t.endsAt.subtract(const Duration(seconds: 1)))}',
                            ),
                            subtitle: (t.reason ?? '').isEmpty
                                ? null
                                : Text(t.reason!),
                            trailing: IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(LucideIcons.trash2, size: 18),
                              onPressed: () async {
                                await ref
                                    .read(doctorScheduleRepositoryProvider)
                                    .deleteTimeOff(t.id);
                                ref.invalidate(_timeOffProvider);
                              },
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addHours(
    BuildContext context,
    WidgetRef ref,
    List<AvailabilityWindow> existing,
  ) async {
    final result = await showDialog<_NewHours>(
      context: context,
      builder: (_) => const _AddHoursDialog(),
    );
    if (result == null || !context.mounted) return;

    final repo = ref.read(doctorScheduleRepositoryProvider);
    final newStart = _minutes(result.start);
    final newEnd = _minutes(result.end);

    final clashes = <String>[];
    var added = 0;
    try {
      for (final day in result.weekdays) {
        final overlaps = existing.any(
          (w) =>
              w.weekday == day &&
              newStart < _minutes(w.end) &&
              newEnd > _minutes(w.start),
        );
        if (overlaps) {
          clashes.add(_weekdayNames[day - 1]);
          continue;
        }
        await repo.addWindow(
          AvailabilityWindow(
            weekday: day,
            start: result.start,
            end: result.end,
            slotMinutes: result.slotMinutes,
          ),
        );
        added++;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    ref.invalidate(_availabilityProvider);
    if (context.mounted && clashes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Skipped ${clashes.join(', ')}: overlaps hours you already set'
            '${added > 0 ? ' ($added added)' : ''}.',
          ),
        ),
      );
    }
  }

  Future<void> _addTimeOff(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Select days off',
    );
    if (range == null || !context.mounted) return;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reason (optional)'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'E.g. Annual leave, conference',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Skip'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(doctorScheduleRepositoryProvider)
          .addTimeOff(
            startsAt: DateTime(
              range.start.year,
              range.start.month,
              range.start.day,
            ),
            endsAt: DateTime(
              range.end.year,
              range.end.month,
              range.end.day + 1,
            ),
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(_timeOffProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.windows,
    required this.onDelete,
  });

  final int day;
  final List<AvailabilityWindow> windows;
  final Future<void> Function(AvailabilityWindow) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_weekdayNames[day - 1], style: theme.titleSmall),
              ),
            ),
            Expanded(
              child: windows.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Not available', style: theme.bodySmall),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final w in windows)
                          InputChip(
                            label: Text(
                              '${w.start} – ${w.end}  ·  ${w.slotMinutes} min',
                            ),
                            onDeleted: () => onDelete(w),
                            deleteIcon: const Icon(LucideIcons.x, size: 16),
                            deleteButtonTooltipMessage: 'Remove',
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewHours {
  const _NewHours(this.weekdays, this.start, this.end, this.slotMinutes);

  final List<int> weekdays;
  final String start;
  final String end;
  final int slotMinutes;
}

class _AddHoursDialog extends StatefulWidget {
  const _AddHoursDialog();

  @override
  State<_AddHoursDialog> createState() => _AddHoursDialogState();
}

class _AddHoursDialogState extends State<_AddHoursDialog> {
  final Set<int> _days = {1, 2, 3, 4, 5};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  int _slot = 30;
  String? _error;

  Future<void> _pick(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isStart ? _start = picked : _end = picked);
    }
  }

  void _submit() {
    final s = _start.hour * 60 + _start.minute;
    final e = _end.hour * 60 + _end.minute;
    if (_days.isEmpty) {
      setState(() => _error = 'Pick at least one day.');
    } else if (e <= s) {
      setState(() => _error = 'End time must be after the start time.');
    } else if (e - s < _slot) {
      setState(
        () => _error = 'That window is shorter than one $_slot-minute slot.',
      );
    } else {
      Navigator.of(context).pop(
        _NewHours(_days.toList()..sort(), _hhmm(_start), _hhmm(_end), _slot),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add weekly hours'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Days', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(_weekdayNames[d - 1].substring(0, 3)),
                      selected: _days.contains(d),
                      onSelected: (sel) => setState(() {
                        sel ? _days.add(d) : _days.remove(d);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _pick(true),
                      icon: const Icon(LucideIcons.clock, size: 16),
                      label: Text('From ${_hhmm(_start)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => _pick(false),
                      icon: const Icon(LucideIcons.clock, size: 16),
                      label: Text('To ${_hhmm(_end)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Appointment length',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [15, 20, 30, 45, 60])
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: _slot == m,
                      onSelected: (_) => setState(() => _slot = m),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
