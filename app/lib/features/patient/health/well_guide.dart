import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/specialty_tiles.dart';

/// One preventive check the Well guide suggests.
class PreventiveCheck {
  const PreventiveCheck({
    required this.key,
    required this.title,
    required this.why,
    required this.everyMonths,
    required this.icon,
    this.minAge = 0,
    this.maxAge,
    this.gender,
    this.specialty,
  });

  final String key;
  final String title;
  final String why;
  final int everyMonths;
  final IconData icon;
  final int minAge;
  final int? maxAge;

  /// 'female' or 'male' when it only applies to one.
  final String? gender;

  /// Where to book it, when a GoDoctor specialty covers it.
  final String? specialty;

  String get howOften => everyMonths % 12 == 0
      ? (everyMonths == 12 ? 'Every year' : 'Every ${everyMonths ~/ 12} years')
      : 'Every $everyMonths months';

  String get whoFor {
    final ages = maxAge != null
        ? 'ages $minAge–$maxAge'
        : minAge > 0
        ? 'from $minAge'
        : 'everyone';
    return switch (gender) {
      'female' => 'Women, $ages',
      'male' => 'Men, $ages',
      _ => minAge > 0 || maxAge != null ? 'Adults, $ages' : 'Everyone',
    };
  }
}

/// General guidance for adults in Kenya. Not a substitute for a doctor's
/// advice, and the screen says so.
const kPreventiveChecks = <PreventiveCheck>[
  PreventiveCheck(
    key: 'bp',
    title: 'Blood pressure check',
    why:
        'High blood pressure has no symptoms but raises the risk of stroke '
        'and heart disease.',
    everyMonths: 12,
    minAge: 18,
    icon: LucideIcons.heartPulse,
    specialty: 'General Practice',
  ),
  PreventiveCheck(
    key: 'weight',
    title: 'Weight and BMI check',
    why: 'Weight changes affect blood pressure and diabetes risk.',
    everyMonths: 12,
    minAge: 18,
    icon: LucideIcons.scale,
    specialty: 'General Practice',
  ),
  PreventiveCheck(
    key: 'hiv',
    title: 'HIV test',
    why: 'Knowing your status early means earlier, free treatment.',
    everyMonths: 12,
    minAge: 15,
    icon: LucideIcons.shieldCheck,
    specialty: 'General Practice',
  ),
  PreventiveCheck(
    key: 'sugar',
    title: 'Blood sugar (diabetes) test',
    why: 'Diabetes often starts quietly. A simple test finds it early.',
    everyMonths: 36,
    minAge: 35,
    icon: LucideIcons.droplet,
    specialty: 'Internal Medicine',
  ),
  PreventiveCheck(
    key: 'cholesterol',
    title: 'Cholesterol test',
    why: 'High cholesterol raises the risk of heart disease and stroke.',
    everyMonths: 60,
    minAge: 40,
    icon: LucideIcons.activity,
    specialty: 'Internal Medicine',
  ),
  PreventiveCheck(
    key: 'cervical',
    title: 'Cervical cancer screening',
    why: 'Screening finds changes early, before they turn into cancer.',
    everyMonths: 36,
    minAge: 25,
    maxAge: 49,
    gender: 'female',
    icon: LucideIcons.venus,
    specialty: 'Obstetrics & Gynaecology',
  ),
  PreventiveCheck(
    key: 'breast',
    title: 'Breast check',
    why: 'A breast exam by a health worker helps find lumps early.',
    everyMonths: 12,
    minAge: 40,
    gender: 'female',
    icon: LucideIcons.ribbon,
    specialty: 'Obstetrics & Gynaecology',
  ),
  PreventiveCheck(
    key: 'prostate',
    title: 'Prostate check',
    why: 'From 50, talk to a doctor about prostate screening.',
    everyMonths: 24,
    minAge: 50,
    gender: 'male',
    icon: LucideIcons.user,
    specialty: 'Internal Medicine',
  ),
  PreventiveCheck(
    key: 'eyes',
    title: 'Eye test',
    why: 'Eyesight changes and glaucoma become more common after 40.',
    everyMonths: 24,
    minAge: 40,
    icon: LucideIcons.eye,
  ),
  PreventiveCheck(
    key: 'dental',
    title: 'Dental check-up',
    why: 'Regular check-ups prevent tooth decay and gum disease.',
    everyMonths: 12,
    icon: LucideIcons.smile,
  ),
];

enum WellStatus { overdue, never, dueSoon, upToDate }

class WellItem {
  const WellItem({
    required this.check,
    required this.status,
    this.lastDone,
    this.dueBy,
  });

  final PreventiveCheck check;
  final WellStatus status;
  final DateTime? lastDone;
  final DateTime? dueBy;

  bool get done =>
      status == WellStatus.upToDate || status == WellStatus.dueSoon;
}

DateTime _addMonths(DateTime d, int months) {
  final m = d.month - 1 + months;
  final y = d.year + m ~/ 12;
  final month = m % 12 + 1;
  final last = DateTime(y, month + 1, 0).day;
  return DateTime(y, month, math.min(d.day, last));
}

/// The checks that fit this patient, with where each one stands: overdue
/// and never-done first. Checks limited by age or gender are left out
/// until the patient's age or gender is known. Pure, for tests.
List<WellItem> wellGuideFor({
  int? age,
  String? gender,
  Map<String, DateTime> done = const {},
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final items = <WellItem>[];
  for (final c in kPreventiveChecks) {
    if (c.gender != null && c.gender != gender) continue;
    if (age == null ? (c.minAge > 18 || c.maxAge != null) : age < c.minAge) {
      continue;
    }
    if (age != null && c.maxAge != null && age > c.maxAge!) continue;
    final last = done[c.key];
    final due = last == null ? null : _addMonths(last, c.everyMonths);
    final status = due == null
        ? WellStatus.never
        : due.isBefore(today)
        ? WellStatus.overdue
        : due.difference(today).inDays <= 60
        ? WellStatus.dueSoon
        : WellStatus.upToDate;
    items.add(WellItem(check: c, status: status, lastDone: last, dueBy: due));
  }
  items.sort((a, b) => a.status.index.compareTo(b.status.index));
  return items;
}

int? ageOn(DateTime? birth, DateTime now) {
  if (birth == null) return null;
  var a = now.year - birth.year;
  if (now.month < birth.month ||
      (now.month == birth.month && now.day < birth.day)) {
    a--;
  }
  return a;
}

final preventiveChecksProvider =
    FutureProvider.autoDispose<Map<String, DateTime>>((ref) {
      if (ref.watch(currentUserIdProvider) == null) return const {};
      return ref.watch(profileRepositoryProvider).preventiveChecks();
    });

/// This patient's Well guide, from their profile and saved checks.
final wellGuideProvider = Provider.autoDispose<AsyncValue<List<WellItem>>>((
  ref,
) {
  final profile = ref.watch(currentPatientProfileProvider);
  final done = ref.watch(preventiveChecksProvider);
  if (done is AsyncError) return AsyncError(done.error!, done.stackTrace!);
  if (!done.hasValue) return const AsyncLoading();
  final p = profile.valueOrNull;
  return AsyncData(
    wellGuideFor(
      age: ageOn(p?.dateOfBirth, DateTime.now()),
      gender: p?.gender,
      done: done.value!,
    ),
  );
});

/// Health tab card: progress ring and what's next.
class WellGuideCard extends ConsumerWidget {
  const WellGuideCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final items = ref.watch(wellGuideProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final done = items.where((i) => i.done).length;
    final next = items.where((i) => !i.done).firstOrNull;
    return Material(
      color: AppColors.warningSoft,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push('/patient/well-guide'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ProgressRing(done: done, total: items.length, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Well guide',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      next == null
                          ? 'All your check-ups are up to date. Well done!'
                          : 'Next: ${next.check.title}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "3/7" inside a ring that fills as checks are done.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.done,
    required this.total,
    this.size = 72,
  });

  final int done;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => CircularProgressIndicator(
              value: v,
              strokeWidth: size / 8,
              strokeCap: StrokeCap.round,
              backgroundColor: AppColors.white,
              color: AppColors.warning,
            ),
          ),
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$done',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: '/$total',
                    style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Well guide: preventive check-ups that fit the patient, To do and Done.
class WellGuideScreen extends ConsumerStatefulWidget {
  const WellGuideScreen({super.key});

  @override
  ConsumerState<WellGuideScreen> createState() => _WellGuideScreenState();
}

class _WellGuideScreenState extends ConsumerState<WellGuideScreen> {
  bool _showDone = false;

  Future<void> _markDone(WellItem item) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'When did you last have it?',
      initialDate: item.lastDone ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    await _save(
      () => ref
          .read(profileRepositoryProvider)
          .markPreventiveCheck(item.check.key, picked),
      'Saved: ${item.check.title}',
    );
  }

  Future<void> _clear(WellItem item) => _save(
    () => ref
        .read(profileRepositoryProvider)
        .clearPreventiveCheck(item.check.key),
    'Removed',
  );

  Future<void> _save(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(preventiveChecksProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(wellGuideProvider);
    final profile = ref.watch(currentPatientProfileProvider).valueOrNull;
    final missingBasics =
        profile != null &&
        (profile.dateOfBirth == null || profile.gender == null);

    return Scaffold(
      appBar: AppBar(title: const Text('Well guide')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(preventiveChecksProvider),
        ),
        data: (items) {
          final done = items.where((i) => i.done).toList();
          final todo = items.where((i) => !i.done).toList();
          final shown = _showDone ? done : todo;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    ProgressRing(done: done.length, total: items.length),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your progress',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check-ups catch problems early, when they\'re '
                            'easiest to treat.',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (missingBasics) ...[
                const SizedBox(height: 12),
                Material(
                  color: AppColors.primarySofter,
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    leading: const Icon(
                      LucideIcons.userRoundPen,
                      color: AppColors.primary,
                    ),
                    title: const Text('Add your date of birth and gender'),
                    subtitle: const Text(
                      'So we can suggest the check-ups that fit you.',
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                    onTap: () => context.push('/patient/profile/account'),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text('To do (${todo.length})'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Done (${done.length})'),
                  ),
                ],
                selected: {_showDone},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _showDone = s.first),
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    _showDone
                        ? 'Mark check-ups as done and they\'ll show here with '
                              'when they\'re next due.'
                        : 'Nothing to do right now. You\'re up to date!',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                ),
              for (var i = 0; i < shown.length; i++)
                FadeSlideIn(
                  key: ValueKey('${_showDone}_${shown[i].check.key}'),
                  index: i,
                  child: _CheckCard(
                    item: shown[i],
                    onDone: () => _markDone(shown[i]),
                    onClear: () => _clear(shown[i]),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'General guidance for adults in Kenya. Your doctor may advise '
                'differently for you.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.item,
    required this.onDone,
    required this.onClear,
  });

  final WellItem item;
  final VoidCallback onDone;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = item.check;
    final month = DateFormat('MMM yyyy');
    final (statusText, statusColor) = switch (item.status) {
      WellStatus.never => ('Not recorded yet', AppColors.inkSoft),
      WellStatus.overdue => (
        'Due since ${month.format(item.dueBy!)}',
        AppColors.danger,
      ),
      WellStatus.dueSoon => (
        'Due ${month.format(item.dueBy!)}',
        AppColors.warning,
      ),
      WellStatus.upToDate => (
        'Up to date until ${month.format(item.dueBy!)}',
        AppColors.success,
      ),
    };
    final meta = c.specialty == null ? null : specialtyMetaFor(c.specialty!);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primarySofter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c.icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: text.titleSmall),
                    Text(
                      '${c.howOften} · ${c.whoFor}',
                      style: text.labelSmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                    if (item.lastDone != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last: ${month.format(item.lastDone!)}',
                        style: text.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      statusText,
                      style: text.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                item.done ? LucideIcons.circleCheck : LucideIcons.circle,
                color: item.done ? AppColors.warning : AppColors.borderStrong,
                size: 24,
              ),
            ],
          ),
          if (!item.done) ...[
            const SizedBox(height: 6),
            Text(
              c.why,
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: onDone,
                icon: const Icon(LucideIcons.check, size: 16),
                label: Text(
                  item.lastDone == null ? 'I\'ve had it' : 'Update date',
                ),
              ),
              if (meta != null && meta.slug.isNotEmpty && !item.done)
                TextButton.icon(
                  onPressed: () =>
                      context.push('/patient/specialty/${meta.slug}'),
                  icon: const Icon(LucideIcons.calendarPlus, size: 16),
                  label: const Text('Book'),
                ),
              if (item.lastDone != null)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                  ),
                  child: const Text('Remove'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
