import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/emergency_check.dart';
import '../widgets/doctor_widgets.dart';
import '../widgets/emergency_stop_view.dart';
import 'doctor_profile_screen.dart' show publicDoctorProvider;

const _horizonDays = 14;

final _openSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlot>, String>((ref, doctorId) {
      final today = DateTime.now();
      return ref
          .watch(doctorDirectoryRepositoryProvider)
          .openSlots(
            doctorId,
            today,
            today.add(const Duration(days: _horizonDays - 1)),
          );
    });

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pick a day and time, describe the reason, confirm. Also used to move an
/// existing appointment when [rescheduleId] is set.
class BookAppointmentScreen extends ConsumerStatefulWidget {
  const BookAppointmentScreen({
    super.key,
    required this.doctorId,
    this.rescheduleId,
  });

  final String doctorId;
  final String? rescheduleId;

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends ConsumerState<BookAppointmentScreen> {
  DateTime? _day;
  TimeSlot? _slot;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;
  EmergencyCheckResult? _emergency;

  bool get _isReschedule => widget.rescheduleId != null;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _canConfirm =>
      _slot != null &&
      !_submitting &&
      (_isReschedule || _reasonCtrl.text.trim().length >= 3);

  Future<void> _confirm(PublicDoctor doctor) async {
    final slot = _slot;
    if (slot == null) return;
    final repo = ref.read(appointmentRepositoryProvider);

    if (!_isReschedule) {
      final check = checkForEmergency([_reasonCtrl.text]);
      if (check.flagged) {
        setState(() => _emergency = check);
        try {
          // Audit trail only -- the server never books an emergency request.
          await repo.book(
            doctorId: doctor.userId,
            start: slot.start,
            specialty: doctor.primarySpecialty,
            reason: _reasonCtrl.text.trim(),
            flaggedEmergency: true,
          );
        } catch (_) {}
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isReschedule) {
        await repo.reschedule(widget.rescheduleId!, slot.start);
        ref.invalidate(upcomingAppointmentsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Moved to ${formatDateTime(slot.start)}')),
        );
        context.pop();
      } else {
        final id = await repo.book(
          doctorId: doctor.userId,
          start: slot.start,
          specialty: doctor.primarySpecialty,
          reason: _reasonCtrl.text.trim(),
        );
        ref.invalidate(upcomingAppointmentsProvider);
        if (!mounted) return;
        context.pushReplacement('/patient/appointment/$id');
      }
    } catch (e) {
      // The slot may have just been taken: refresh the list so it disappears.
      ref.invalidate(_openSlotsProvider(widget.doctorId));
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _slot = null;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_emergency != null) {
      return EmergencyStopView(matchedKeyword: _emergency!.matchedKeyword);
    }

    final doctorAsync = ref.watch(publicDoctorProvider(widget.doctorId));
    final slotsAsync = ref.watch(_openSlotsProvider(widget.doctorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isReschedule ? 'Reschedule' : 'Book appointment'),
      ),
      body: doctorAsync.when(
        loading: () => const SkeletonList(itemCount: 3),
        error: (e, _) => ErrorView(message: friendlyError(e)),
        data: (doctor) {
          if (doctor == null) {
            return const EmptyView(
              message: 'This doctor is not available.',
              icon: LucideIcons.userX,
            );
          }
          return slotsAsync.when(
            loading: () => const SkeletonList(itemCount: 4),
            error: (e, _) => ErrorView(
              message: friendlyError(e),
              onRetry: () =>
                  ref.invalidate(_openSlotsProvider(widget.doctorId)),
            ),
            data: (slots) => _buildForm(context, doctor, slots),
          );
        },
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    PublicDoctor doctor,
    List<TimeSlot> slots,
  ) {
    final theme = Theme.of(context).textTheme;

    final byDay = <DateTime, List<TimeSlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(_dateOnly(s.start), () => []).add(s);
    }
    final today = _dateOnly(DateTime.now());
    final days = [
      for (var i = 0; i < _horizonDays; i++) today.add(Duration(days: i)),
    ];

    // Default to the first day that has any slot.
    _day ??= days.firstWhere(byDay.containsKey, orElse: () => today);
    final daySlots = byDay[_day] ?? const <TimeSlot>[];

    List<TimeSlot> part(bool Function(int hour) test) =>
        daySlots.where((s) => test(s.start.hour)).toList();
    final morning = part((h) => h < 12);
    final afternoon = part((h) => h >= 12 && h < 17);
    final evening = part((h) => h >= 17);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              Row(
                children: [
                  DoctorAvatar(
                    name: doctor.name,
                    avatarPath: doctor.avatarPath,
                    radius: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctor.name, style: theme.titleSmall),
                        Text(doctor.primarySpecialty, style: theme.bodySmall),
                      ],
                    ),
                  ),
                  Text(
                    formatKes(doctor.consultationFee),
                    style: theme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text('Choose a day', style: theme.titleMedium),
              const SizedBox(height: 10),
              SizedBox(
                height: 78,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final has = byDay.containsKey(d);
                    return _DayTile(
                      day: d,
                      enabled: has,
                      selected: _day == d,
                      onTap: () => setState(() {
                        _day = d;
                        _slot = null;
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              if (byDay.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'This doctor has no open slots in the next $_horizonDays days.',
                    style: theme.bodyMedium,
                  ),
                )
              else ...[
                Text('Choose a time', style: theme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Times are shown in your local time.',
                  style: theme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (daySlots.isEmpty)
                  Text('No slots on this day.', style: theme.bodyMedium),
                _SlotGroup(
                  title: 'Morning',
                  icon: LucideIcons.sunrise,
                  slots: morning,
                  selected: _slot,
                  onPick: (s) => setState(() => _slot = s),
                ),
                _SlotGroup(
                  title: 'Afternoon',
                  icon: LucideIcons.sun,
                  slots: afternoon,
                  selected: _slot,
                  onPick: (s) => setState(() => _slot = s),
                ),
                _SlotGroup(
                  title: 'Evening',
                  icon: LucideIcons.moon,
                  slots: evening,
                  selected: _slot,
                  onPick: (s) => setState(() => _slot = s),
                ),
              ],
              if (!_isReschedule) ...[
                const SizedBox(height: 22),
                Text(
                  'What would you like to discuss?',
                  style: theme.titleMedium,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText:
                        'Briefly describe your symptoms or reason for the visit',
                  ),
                ),
              ],
              if (_slot != null) ...[
                const SizedBox(height: 22),
                _Summary(doctor: doctor, slot: _slot!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.circleAlert,
                        color: AppColors.danger,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: FilledButton(
              onPressed: _canConfirm ? () => _confirm(doctor) : null,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isReschedule ? 'Confirm new time' : 'Confirm booking',
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weekday = const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][day.weekday - 1];
    final fg = selected
        ? Colors.white
        : enabled
        ? AppColors.ink
        : AppColors.inkFaint;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '$weekday ${day.day}${enabled ? '' : ', no slots'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 58,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : (enabled ? AppColors.white : AppColors.border),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                weekday,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${day.day}',
                style: TextStyle(
                  color: fg,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (enabled && !selected)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotGroup extends StatelessWidget {
  const _SlotGroup({
    required this.title,
    required this.icon,
    required this.slots,
    required this.selected,
    required this.onPick,
  });

  final String title;
  final IconData icon;
  final List<TimeSlot> slots;
  final TimeSlot? selected;
  final ValueChanged<TimeSlot> onPick;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.inkFaint),
              const SizedBox(width: 6),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text(formatTime(s.start)),
                  selected: selected?.start == s.start,
                  onSelected: (_) => onPick(s),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.doctor, required this.slot});

  final PublicDoctor doctor;
  final TimeSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final minutes = slot.end.difference(slot.start).inMinutes;

    Widget row(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.bodyMedium?.copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your appointment', style: theme.titleSmall),
          const SizedBox(height: 8),
          row(LucideIcons.calendarDays, formatDateTime(slot.start)),
          row(LucideIcons.clock, '$minutes minute video consultation'),
          row(LucideIcons.banknote, formatKes(doctor.consultationFee)),
          const SizedBox(height: 6),
          Text(
            'Online payment is not switched on yet, so nothing is charged when you book.',
            style: theme.bodySmall,
          ),
        ],
      ),
    );
  }
}
