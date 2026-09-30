import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/design_kit.dart';
import '../../core/widgets/motion.dart';
import '../patient/home/mood_check_in.dart';
import 'selfcare_content.dart';
import '../patient/widgets/specialty_tiles.dart' show PageDashes;
import 'stick_scene.dart';

const _page = Color(0xFFF4F4F8);
const _featuredTopic = 'regulate-emotions';

// ---------------------------------------------------------------------------
// What you've done (kept on this phone)
// ---------------------------------------------------------------------------

class SelfCareLog {
  const SelfCareLog(this.entries);

  /// (item id, when), newest last.
  final List<(String, DateTime)> entries;

  Set<String> get doneIds => {for (final (id, _) in entries) id};

  /// Practices finished in the last 7 days.
  int thisWeek(DateTime now) => entries
      .where((e) => now.difference(e.$2) < const Duration(days: 7))
      .length;

  static const _key = 'selfcare_log';

  static Future<SelfCareLog> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const [];
      return SelfCareLog([
        for (final line in raw)
          if (line.split('|') case [
            final id,
            final at,
          ] when DateTime.tryParse(at) != null)
            (id, DateTime.parse(at)),
      ]);
    } catch (_) {
      return const SelfCareLog([]);
    }
  }

  static Future<void> add(String itemId, DateTime at) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = [
        ...?prefs.getStringList(_key),
        '$itemId|${at.toIso8601String()}',
      ];
      await prefs.setStringList(
        _key,
        raw.length > 200 ? raw.sublist(raw.length - 200) : raw,
      );
    } catch (_) {}
  }
}

final selfCareLogProvider = FutureProvider.autoDispose<SelfCareLog>(
  (ref) => SelfCareLog.load(),
);

// ---------------------------------------------------------------------------
// Self-care practices: the grid
// ---------------------------------------------------------------------------

/// "Self-care practices": everything, as a two-column grid of soft cards,
/// filtered by All / Practices / Tips / Guides.
class SelfCareScreen extends ConsumerStatefulWidget {
  const SelfCareScreen({super.key});

  @override
  ConsumerState<SelfCareScreen> createState() => _SelfCareScreenState();
}

class _SelfCareScreenState extends ConsumerState<SelfCareScreen> {
  CareKind? _kind;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final week =
        ref.watch(selfCareLogProvider).valueOrNull?.thisWeek(DateTime.now()) ??
        0;
    final topics = [
      for (final t in kCareTopics)
        if (_kind == null || t.kind == _kind) t,
    ];
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                const SizedBox(width: 44),
                Expanded(
                  child: Text(
                    'Self-care practices',
                    textAlign: TextAlign.center,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Material(
                  color: AppColors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go('/patient/health'),
                  ),
                ),
              ],
            ),
            if (week > 0) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  '$week done this week. Keep going!',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _KindChip(
                    label: 'All',
                    selected: _kind == null,
                    onTap: () => setState(() => _kind = null),
                  ),
                  for (final k in CareKind.values)
                    _KindChip(
                      label: k.label,
                      selected: _kind == k,
                      onTap: () => setState(() => _kind = k),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _TopicGrid(key: ValueKey(_kind), topics: topics),
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? AppColors.lavender : AppColors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? AppColors.white : AppColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two columns, each card as tall as it needs; the featured card is tall
/// and yellow, so the columns stagger.
class _TopicGrid extends StatelessWidget {
  const _TopicGrid({super.key, required this.topics});

  final List<CareTopic> topics;

  @override
  Widget build(BuildContext context) {
    final left = <CareTopic>[], right = <CareTopic>[];
    var lh = 0.0, rh = 0.0;
    for (final t in topics) {
      final h = t.id == _featuredTopic
          ? 230.0
          : 128.0 + (t.title.length > 15 ? 22 : 0);
      if (lh <= rh) {
        left.add(t);
        lh += h;
      } else {
        right.add(t);
        rh += h;
      }
    }
    Widget column(List<CareTopic> list) => Column(
      children: [
        for (final (i, t) in list.indexed) ...[
          FadeSlideIn(
            index: i,
            child: t.id == _featuredTopic
                ? _FeaturedCard(topic: t)
                : _TopicCard(topic: t),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(left)),
        const SizedBox(width: 12),
        Expanded(child: column(right)),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final CareTopic topic;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/patient/selfcare/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(topic.icon, size: 22, color: topic.color),
                const SizedBox(height: 22),
                Text(
                  topic.title,
                  maxLines: 3,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  topic.countLabel,
                  style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.topic});

  final CareTopic topic;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Pressable(
      child: Material(
        color: topic.color,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.push('/patient/selfcare/${topic.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(topic.icon, size: 20, color: AppColors.ink),
                ),
                const SizedBox(height: 18),
                Text(
                  topic.title,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  topic.countLabel,
                  style: text.bodySmall?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => context.push(
                      '/patient/practice/${topic.items.first.id}',
                    ),
                    icon: const Icon(LucideIcons.play, size: 16),
                    label: const Text('Start'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One topic
// ---------------------------------------------------------------------------

class SelfCareTopicScreen extends ConsumerWidget {
  const SelfCareTopicScreen({super.key, required this.topicId});

  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final topic = careTopic(topicId);
    if (topic == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('We couldn\'t find that.')),
      );
    }
    final done = ref.watch(selfCareLogProvider).valueOrNull?.doneIds ?? {};
    final minutes = topic.items.fold<int>(0, (s, i) => s + i.minutes);
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(backgroundColor: _page),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                topic.color.withValues(alpha: 0.16),
                AppColors.white,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(topic.icon, color: topic.color, size: 24),
                ),
                const SizedBox(height: 14),
                Text(
                  topic.title,
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(topic.blurb, style: text.bodyMedium),
                const SizedBox(height: 10),
                Text(
                  '${topic.countLabel} · about $minutes min in all',
                  style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
                ),
                if (topic.link case (final label, final route)) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.white,
                    ),
                    onPressed: () => context.push(route),
                    icon: const Icon(LucideIcons.activity, size: 16),
                    label: Text(label),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, item) in topic.items.indexed)
            FadeSlideIn(
              index: i,
              child: _ItemTile(
                topic: topic,
                item: item,
                done: done.contains(item.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.topic,
    required this.item,
    required this.done,
  });

  final CareTopic topic;
  final CareItem item;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final what = item.breathing != null
        ? 'Guided breathing'
        : switch (topic.kind) {
            CareKind.practice => 'Practice',
            CareKind.tip => 'Tip',
            CareKind.guide => 'Read',
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/patient/practice/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.successSoft
                        : topic.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    done ? LucideIcons.check : topic.icon,
                    size: 18,
                    color: done ? AppColors.success : topic.color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        item.why,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.minutes} min · $what',
                        style: text.labelSmall?.copyWith(
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 18,
                  color: AppColors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doing one
// ---------------------------------------------------------------------------

/// One practice: a step at a time (or, for breathing, a circle that grows
/// and shrinks with you); tips and guides read as a short page. Ends with a
/// quiet "nicely done".
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({super.key, required this.itemId, this.from});

  final String itemId;

  /// A [StickSceneKind] name: how she was on the screen before (the mood
  /// card), so she carries on from there.
  final String? from;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  int _step = 0;
  bool _done = false;

  Future<void> _finish(CareItem item) async {
    HapticFeedback.mediumImpact();
    setState(() => _done = true);
    await SelfCareLog.add(item.id, DateTime.now());
    ref.invalidate(selfCareLogProvider);
  }

  @override
  Widget build(BuildContext context) {
    final found = careItem(widget.itemId);
    if (found == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('We couldn\'t find that.')),
      );
    }
    final (topic, item) = found;
    final text = Theme.of(context).textTheme;
    final tint = Color.alphaBlend(
      topic.color.withValues(alpha: 0.14),
      AppColors.white,
    );
    final reading = topic.kind != CareKind.practice;
    final emotional = const {
      'regulate-emotions',
      'keep-calm',
      'good-mood',
      'managing-stress',
    }.contains(topic.id);

    final Widget body;
    if (_done) {
      final week =
          ref
              .watch(selfCareLogProvider)
              .valueOrNull
              ?.thisWeek(DateTime.now()) ??
          1;
      final next = topic.items
          .skipWhile((i) => i.id != item.id)
          .skip(1)
          .firstOrNull;
      body = _DoneView(
        week: week,
        reading: reading,
        next: next,
        cheer: item.scenes == null ? null : item.doneScene,
        cheerFrom: item.scenes?.last,
        onBack: () => context.canPop()
            ? context.pop()
            : context.go('/patient/selfcare/${topic.id}'),
      );
    } else if (item.breathing != null) {
      body = _Breather(
        key: ValueKey(item.id),
        pattern: item.breathing!,
        color: topic.color,
        steps: item.steps,
        onFinished: () => _finish(item),
      );
    } else if (reading) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          for (final s in item.steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: topic.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s, style: text.bodyLarge)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
            onPressed: () => _finish(item),
            child: const Text('Got it'),
          ),
        ],
      );
    } else {
      final last = _step == item.steps.length - 1;
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageDashes(count: item.steps.length, current: _step),
            const SizedBox(height: 18),
            if (item.scenes case final scenes?)
              // The scene stays put and moves from one step to the next;
              // the words change under it.
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: LayoutBuilder(
                    builder: (context, c) => Column(
                      children: [
                        // As big as the drawing needs (4:3), leaving room
                        // for the words on a short screen.
                        SizedBox(
                          height: (c.maxWidth * 0.75).clamp(
                            0.0,
                            c.maxHeight * 0.64,
                          ),
                          width: double.infinity,
                          child: StickScene(
                            scene: scenes[_step],
                            from:
                                StickSceneKind.values
                                    .where((k) => k.name == widget.from)
                                    .firstOrNull ??
                                item.opening,
                          ),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            child: Center(
                              key: ValueKey(_step),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  item.steps[_step],
                                  textAlign: TextAlign.center,
                                  style: text.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.08, 0),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: Container(
                    key: ValueKey(_step),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          item.steps[_step],
                          textAlign: TextAlign.center,
                          style: text.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (_step > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.white,
                        minimumSize: const Size(56, 52),
                      ),
                      onPressed: () => setState(() => _step--),
                      child: const Icon(LucideIcons.arrowLeft, size: 18),
                    ),
                  ),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (last) {
                        _finish(item);
                      } else {
                        setState(() => _step++);
                      }
                    },
                    child: Text(last ? 'I did it' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: tint,
      appBar: AppBar(
        backgroundColor: tint,
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(LucideIcons.x),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/patient/selfcare'),
        ),
        title: Text(topic.title, style: text.titleSmall),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.clock,
                  size: 14,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 4),
                Text('${item.minutes} min', style: text.labelMedium),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_done)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.why,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: body),
            if (emotional && !_done)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'Feeling unsafe or in crisis? Call 999 or 1199 now.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.week,
    required this.reading,
    required this.next,
    required this.onBack,
    this.cheer,
    this.cheerFrom,
  });

  final int week;
  final bool reading;
  final CareItem? next;
  final VoidCallback onBack;

  /// For practices with a scene: how she ends up (jumping for joy, or
  /// asleep), moving there from her last pose, instead of the check mark.
  final StickSceneKind? cheer;
  final StickSceneKind? cheerFrom;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cheer != null)
              SizedBox(
                height: 210,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: StickScene(scene: cheer!, from: cheerFrom),
                ),
              )
            else
              const AnimatedCheck(size: 88, haptic: false),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 1,
              child: Text(
                reading ? 'Good to know.' : 'Nicely done.',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeSlideIn(
              index: 2,
              child: Text(
                week <= 1
                    ? 'A small step for you today.'
                    : '$week done this week. That adds up.',
                textAlign: TextAlign.center,
                style: text.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            if (next != null)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  minimumSize: const Size(220, 50),
                ),
                onPressed: () =>
                    context.pushReplacement('/patient/practice/${next!.id}'),
                child: Text('Next: ${next!.title}'),
              ),
            const SizedBox(height: 8),
            TextButton(onPressed: onBack, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

/// Breathe with the circle: it grows as you breathe in, rests while you
/// hold, and shrinks as you breathe out.
class _Breather extends StatefulWidget {
  const _Breather({
    super.key,
    required this.pattern,
    required this.color,
    required this.steps,
    required this.onFinished,
  });

  final BreathPattern pattern;
  final Color color;
  final List<String> steps;
  final VoidCallback onFinished;

  @override
  State<_Breather> createState() => _BreatherState();
}

class _BreatherState extends State<_Breather>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.pattern.roundSeconds),
  );
  int _round = 0;
  bool _running = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      if (_round + 1 >= widget.pattern.rounds) {
        _tick?.cancel();
        setState(() => _running = false);
        widget.onFinished();
      } else {
        setState(() => _round++);
        _c.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _running = !_running);
    if (_running) {
      _c.forward();
      // A soft tap as each phase changes.
      var last = '';
      _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final p = _phase().$1;
        if (p != last) {
          last = p;
          HapticFeedback.lightImpact();
        }
      });
    } else {
      _c.stop();
      _tick?.cancel();
    }
  }

  /// (what to do, seconds left in it, circle size 0..1)
  (String, int, double) _phase() {
    final p = widget.pattern;
    final t = _c.value * p.roundSeconds;
    if (t < p.inhale) {
      return ('Breathe in', (p.inhale - t).ceil(), t / p.inhale);
    }
    if (t < p.inhale + p.hold) {
      return ('Hold', (p.inhale + p.hold - t).ceil(), 1);
    }
    if (t < p.inhale + p.hold + p.exhale) {
      final into = t - p.inhale - p.hold;
      return ('Breathe out', (p.exhale - into).ceil(), 1 - into / p.exhale);
    }
    return ('Hold', (p.roundSeconds - t).ceil(), 0);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        final big = (c.maxHeight * 0.5).clamp(160.0, 280.0);
        return Column(
          children: [
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final (label, left, size) = _running || _c.value > 0
                        ? _phase()
                        : ('Ready when you are', 0, 0.0);
                    final eased = Curves.easeInOut.transform(
                      size.clamp(0.0, 1.0),
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // She breathes with you: the ring around her
                        // grows as you breathe in and shrinks as you
                        // breathe out.
                        SizedBox(
                          height: big,
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                StickScene(
                                  scene: StickSceneKind.calmSit,
                                  breath: eased,
                                ),
                                if (left > 0)
                                  Positioned(
                                    top: 10,
                                    right: 12,
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: widget.color,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '$left',
                                        style: text.titleLarge?.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          label,
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Round ${_round + 1} of ${widget.pattern.rounds}',
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.steps.join(' '),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  minimumSize: const Size(double.infinity, 52),
                ),
                onPressed: _toggle,
                icon: Icon(
                  _running ? LucideIcons.pause : LucideIcons.play,
                  size: 18,
                ),
                label: Text(
                  _running
                      ? 'Pause'
                      : _c.value > 0
                      ? 'Carry on'
                      : 'Start',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// On the Health tab and on Home
// ---------------------------------------------------------------------------

/// On the Health tab: a row of self-care topics, today's suggestion first.
class SelfCareSection extends ConsumerWidget {
  const SelfCareSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mood = ref.watch(todaysMoodProvider).valueOrNull;
    final suggested = suggestPractice(DateTime.now(), mood: mood?.key);
    final first = suggested?.$1 ?? careTopic(_featuredTopic)!;
    final topics = [
      first,
      for (final t in kCareTopics)
        if (t.id != first.id && t.kind == CareKind.practice) t,
    ].take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Self-care practices',
          padding: EdgeInsets.zero,
          onMore: () => context.push('/patient/selfcare'),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: topics.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = topics[i];
              final lead = i == 0;
              return SizedBox(
                width: 140,
                child: Material(
                  color: lead ? t.color : AppColors.white,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => lead && suggested != null
                        ? context.push('/patient/practice/${suggested.$2.id}')
                        : context.push('/patient/selfcare/${t.id}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            t.icon,
                            size: 20,
                            color: lead ? AppColors.ink : t.color,
                          ),
                          const Spacer(),
                          Text(
                            lead && suggested != null
                                ? suggested.$2.title
                                : t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lead && suggested != null
                                ? 'For today · ${suggested.$2.minutes} min'
                                : t.countLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: lead
                                      ? AppColors.ink
                                      : AppColors.inkFaint,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// On Home, now and then: one small practice for this time of day.
class SelfCareSuggestionCard extends ConsumerWidget {
  const SelfCareSuggestionCard({super.key, this.padding = EdgeInsets.zero});

  /// Around the card, only when it shows.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A feeling picked today already comes with its own suggestion.
    if (ref.watch(todaysMoodProvider).valueOrNull != null) {
      return const SizedBox.shrink();
    }
    final pick = suggestPractice(DateTime.now());
    if (pick == null) return const SizedBox.shrink();
    final (topic, item) = pick;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Pressable(
        child: Material(
          color: Color.alphaBlend(
            topic.color.withValues(alpha: 0.16),
            AppColors.white,
          ),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/patient/practice/${item.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(topic.icon, color: topic.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Self-care · ${item.minutes} min',
                          style: text.labelMedium?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.play,
                          size: 14,
                          color: AppColors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Start',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
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
