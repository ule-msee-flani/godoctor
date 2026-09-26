import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/medication.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';
import 'medication_providers.dart';

/// "Remind me to take these": one row per medicine with reminder times and
/// course length read from the doctor's instructions (editable). Reminders
/// arrive as push notifications.
Future<void> showDoseReminderSheet(
  BuildContext context, {
  required List<PrescriptionItem> items,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DoseReminderSheet(items: items),
  );
}

class _Draft {
  _Draft(this.item)
    : plan = planDoses(
        dosage: item.dosage,
        instructions: item.instructions,
        quantity: item.quantity,
      ) {
    times = [...plan.times];
    days = plan.days;
  }

  final PrescriptionItem item;
  final DosePlan plan;
  late List<String> times;
  late int days;
  bool on = true;
}

class _DoseReminderSheet extends ConsumerStatefulWidget {
  const _DoseReminderSheet({required this.items});

  final List<PrescriptionItem> items;

  @override
  ConsumerState<_DoseReminderSheet> createState() => _DoseReminderSheetState();
}

class _DoseReminderSheetState extends ConsumerState<_DoseReminderSheet> {
  late final List<_Draft> _drafts = [for (final i in widget.items) _Draft(i)];
  bool _saving = false;

  Future<void> _editTime(_Draft d, int index) async {
    final parts = d.times[index].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;
    setState(() {
      d.times[index] =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
      d.times.sort();
    });
  }

  Future<void> _save(Set<String> alreadyOn) async {
    final chosen = [
      for (final d in _drafts)
        if (d.on && !alreadyOn.contains(d.item.id)) d,
    ];
    if (chosen.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = ref.read(medicationRepositoryProvider);
      for (final d in chosen) {
        await repo.create(
          drugName: d.item.displayName,
          dosage: d.item.dosage,
          prescriptionItemId: d.item.id,
          times: d.times,
          days: d.days,
        );
      }
      ref.invalidate(activeSchedulesProvider);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.pop(context);
      final first = chosen.first.times.join(' and ');
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            chosen.length == 1
                ? 'Reminders set. We\'ll remind you at $first.'
                : 'Reminders set for ${chosen.length} medicines.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final existing = ref.watch(activeSchedulesProvider).valueOrNull ?? const [];
    final alreadyOn = {
      for (final s in existing)
        if (s.prescriptionItemId != null) s.prescriptionItemId!,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dose reminders', style: theme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'We\'ll send a notification when each dose is due. Tap a time '
              'to change it.',
              style: theme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _drafts.length,
                separatorBuilder: (_, _) => const Divider(height: 20),
                itemBuilder: (context, i) {
                  final d = _drafts[i];
                  final on = alreadyOn.contains(d.item.id);
                  return _DraftRow(
                    draft: d,
                    alreadyOn: on,
                    onToggle: on ? null : (v) => setState(() => d.on = v),
                    onEditTime: (t) => _editTime(d, t),
                    onDays: (v) => setState(() => d.days = v),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(alreadyOn),
              icon: const Icon(LucideIcons.alarmClock, size: 18),
              label: Text(_saving ? 'Saving...' : 'Set reminders'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftRow extends StatelessWidget {
  const _DraftRow({
    required this.draft,
    required this.alreadyOn,
    required this.onToggle,
    required this.onEditTime,
    required this.onDays,
  });

  final _Draft draft;
  final bool alreadyOn;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<int> onEditTime;
  final ValueChanged<int> onDays;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final item = draft.item;
    final enabled = draft.on && !alreadyOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName, style: theme.titleSmall),
                  Text(
                    [
                      if (item.dosage?.isNotEmpty ?? false) item.dosage!,
                      if (item.instructions?.isNotEmpty ?? false)
                        item.instructions!,
                    ].join(' · '),
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            if (alreadyOn)
              Text(
                'Reminder on',
                style: theme.labelMedium?.copyWith(color: AppColors.success),
              )
            else
              Switch(value: draft.on, onChanged: onToggle),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var t = 0; t < draft.times.length; t++)
                ActionChip(
                  avatar: const Icon(LucideIcons.clock, size: 14),
                  label: Text(draft.times[t]),
                  onPressed: () => onEditTime(t),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('For', style: theme.bodyMedium),
              IconButton(
                tooltip: 'Fewer days',
                icon: const Icon(LucideIcons.minus, size: 16),
                onPressed: draft.days > 1 ? () => onDays(draft.days - 1) : null,
              ),
              Text(
                '${draft.days} ${draft.days == 1 ? 'day' : 'days'}',
                style: theme.titleSmall,
              ),
              IconButton(
                tooltip: 'More days',
                icon: const Icon(LucideIcons.plus, size: 16),
                onPressed: draft.days < 90
                    ? () => onDays(draft.days + 1)
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }
}
