import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/health_reading.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';

/// The three things a patient can track.
enum ReadingKind { bp, sugar, weight }

extension ReadingKindLook on ReadingKind {
  String get label => switch (this) {
    ReadingKind.bp => 'Blood pressure',
    ReadingKind.sugar => 'Blood sugar',
    ReadingKind.weight => 'Weight',
  };

  IconData get icon => switch (this) {
    ReadingKind.bp => LucideIcons.heartPulse,
    ReadingKind.sugar => LucideIcons.droplet,
    ReadingKind.weight => LucideIcons.scale,
  };

  Gradient get gradient => switch (this) {
    ReadingKind.bp => AppColors.skyGradient,
    ReadingKind.sugar => AppColors.peachGradient,
    ReadingKind.weight => AppColors.mintGradient,
  };

  /// The healthy band shaded on the chart (null: none).
  (double, double)? get healthy => switch (this) {
    ReadingKind.bp => (90, 120),
    ReadingKind.sugar => (3.9, 5.6),
    ReadingKind.weight => null,
  };
}

// Two series on the blood pressure chart (checked for colour-blind
// separation); every other chart has one line.
const _systolic = AppColors.primary;
const _diastolic = Color(0xFFE9804C);

final readingsProvider = FutureProvider.autoDispose
    .family<List<HealthReading>, ReadingKind>((ref, kind) {
      ref.watch(liveTick(LiveTable.readings));
      if (ref.watch(currentUserIdProvider) == null) return const [];
      return ref.watch(profileRepositoryProvider).readings(kind: kind.name);
    });

/// Level colours and icons: status colours, always with a word.
(Color, IconData) levelLook(ReadingLevel l) => switch (l) {
  ReadingLevel.normal => (AppColors.success, LucideIcons.circleCheck),
  ReadingLevel.borderline => (AppColors.warning, LucideIcons.circleAlert),
  ReadingLevel.low ||
  ReadingLevel.high => (AppColors.danger, LucideIcons.triangleAlert),
  ReadingLevel.urgent => (AppColors.danger, LucideIcons.siren),
};

/// Health tab: "Your numbers" — latest blood pressure, sugar and weight.
class YourNumbersCard extends ConsumerWidget {
  const YourNumbersCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Your numbers',
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push('/patient/readings'),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Log'),
            ),
          ],
        ),
        Row(
          children: [
            for (final k in ReadingKind.values) ...[
              if (k != ReadingKind.bp) const SizedBox(width: 8),
              Expanded(child: _NumberTile(kind: k)),
            ],
          ],
        ),
      ],
    );
  }
}

class _NumberTile extends ConsumerWidget {
  const _NumberTile({required this.kind});

  final ReadingKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final latest = ref.watch(readingsProvider(kind)).valueOrNull?.firstOrNull;
    final level = latest == null ? null : readingLevel(latest);
    return Material(
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: kind.gradient),
        child: InkWell(
          onTap: () => context.push('/patient/readings?kind=${kind.name}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(kind.icon, size: 18, color: AppColors.ink),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    latest?.display ?? '—',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  latest == null ? kind.label : level?.label ?? latest.unit,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(
                    color: level == null
                        ? AppColors.inkSoft
                        : levelLook(level.level).$1,
                    fontWeight: level == null ? null : FontWeight.w700,
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

/// Track blood pressure, sugar and weight: the latest number big, the
/// trend, and every reading.
class ReadingsScreen extends ConsumerStatefulWidget {
  const ReadingsScreen({super.key, this.initial});

  /// 'bp', 'sugar' or 'weight'.
  final String? initial;

  @override
  ConsumerState<ReadingsScreen> createState() => _ReadingsScreenState();
}

class _ReadingsScreenState extends ConsumerState<ReadingsScreen> {
  late ReadingKind _kind = ReadingKind.values.firstWhere(
    (k) => k.name == widget.initial,
    orElse: () => ReadingKind.bp,
  );

  Future<void> _add() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddReadingSheet(kind: _kind),
    );
    if (added == true) ref.invalidate(readingsProvider(_kind));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final async = ref.watch(readingsProvider(_kind));
    return Scaffold(
      appBar: AppBar(title: const Text('Your numbers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(LucideIcons.plus),
        label: Text('Add ${_kind.label.toLowerCase()}'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          SegmentedButton<ReadingKind>(
            showSelectedIcon: false,
            segments: [
              for (final k in ReadingKind.values)
                ButtonSegment(
                  value: k,
                  label: Text(
                    k == ReadingKind.bp
                        ? 'Pressure'
                        : k == ReadingKind.sugar
                        ? 'Sugar'
                        : 'Weight',
                  ),
                  icon: Icon(k.icon, size: 16),
                ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          ...async.when(
            loading: () => const [
              SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [ErrorView(message: friendlyError(e))],
            data: (list) {
              if (list.isEmpty) {
                return [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: _kind.gradient,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Icon(_kind.icon, size: 36, color: AppColors.ink),
                        const SizedBox(height: 10),
                        Text(
                          'No ${_kind.label.toLowerCase()} readings yet',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Log one after each check and see how it changes. '
                          'Your doctor sees your latest numbers too.',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ];
              }
              return [
                _Latest(kind: _kind, reading: list.first),
                if (list.length >= 2) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Trend',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_kind == ReadingKind.bp) const _Legend(),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 210,
                    child: ReadingsChart(
                      kind: _kind,
                      readings: list.reversed.take(30).toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'All readings',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final r in list) _ReadingRow(reading: r),
                const SizedBox(height: 12),
                Text(
                  'General guidance for adults. If a reading worries you, '
                  'talk to a doctor.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _Latest extends StatelessWidget {
  const _Latest({required this.kind, required this.reading});

  final ReadingKind kind;
  final HealthReading reading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = readingLevel(reading);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kind.gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest · ${DateFormat('EEE d MMM, h:mm a').format(reading.takenAt)}',
            style: text.labelMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    reading.display,
                    style: text.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  reading.unit,
                  style: text.titleMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          if (level != null) ...[
            const SizedBox(height: 12),
            _LevelChip(level: level.level, label: level.label),
          ],
          if (reading.context != null) ...[
            const SizedBox(height: 6),
            Text(switch (reading.context) {
              'fasting' => 'Before eating',
              'after_meal' => 'After a meal',
              _ => 'Any time',
            }, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.level, required this.label});

  final ReadingLevel level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = levelLook(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(t, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 16,
        children: [
          item(_systolic, 'Top (systolic)'),
          item(_diastolic, 'Bottom (diastolic)'),
        ],
      ),
    );
  }
}

/// The readings over time: thin lines, the healthy range shaded, the
/// latest point marked, and tap for the value.
class ReadingsChart extends StatelessWidget {
  const ReadingsChart({super.key, required this.kind, required this.readings});

  final ReadingKind kind;

  /// Oldest first.
  final List<HealthReading> readings;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.inkSoft);
    final values = [
      for (final r in readings) ...[r.value, ?r.value2],
    ];
    final band = kind.healthy;
    var lo = [...values, ?band?.$1].reduce((a, b) => a < b ? a : b);
    var hi = [...values, ?band?.$2].reduce((a, b) => a > b ? a : b);
    final pad = (hi - lo).abs() < 1 ? 2.0 : (hi - lo) * 0.15;
    lo = (lo - pad).floorToDouble();
    hi = (hi + pad).ceilToDouble();
    final last = readings.length - 1;
    final fmt = DateFormat('d MMM');

    LineChartBarData line(Color color, double Function(HealthReading) y) =>
        LineChartBarData(
          spots: [
            for (var i = 0; i < readings.length; i++)
              FlSpot(i.toDouble(), y(readings[i])),
          ],
          color: color,
          barWidth: 2,
          isCurved: true,
          preventCurveOverShooting: true,
          isStrokeCapRound: true,
          dotData: FlDotData(
            getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
              radius: spot.x == last ? 5 : 3,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
        );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: last.toDouble(),
        minY: lo,
        maxY: hi,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: ((hi - lo) / 4).clamp(0.5, 1000),
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: AppColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (band != null)
              HorizontalRangeAnnotation(
                y1: band.$1,
                y2: band.$2,
                color: AppColors.success.withValues(alpha: 0.08),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: ((hi - lo) / 4).clamp(0.5, 1000),
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  v.toStringAsFixed(kind == ReadingKind.sugar ? 1 : 0),
                  style: small,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                final every = (readings.length / 4).ceil().clamp(1, 100);
                if (i < 0 || i > last || (last - i) % every != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(fmt.format(readings[i].takenAt), style: small),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  s.y.toStringAsFixed(kind == ReadingKind.sugar ? 1 : 0),
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    if (s == spots.last)
                      TextSpan(
                        text: '\n${fmt.format(readings[s.x.round()].takenAt)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          line(_systolic, (r) => r.value),
          if (kind == ReadingKind.bp)
            line(_diastolic, (r) => r.value2 ?? r.value),
        ],
      ),
    );
  }
}

class _ReadingRow extends ConsumerWidget {
  const _ReadingRow({required this.reading});

  final HealthReading reading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final level = readingLevel(reading);
    return Dismissible(
      key: ValueKey(reading.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.dangerSoft,
        child: const Icon(LucideIcons.trash2, color: AppColors.danger),
      ),
      onDismissed: (_) async {
        try {
          await ref.read(profileRepositoryProvider).deleteReading(reading.id);
        } catch (_) {}
        ref.invalidate(readingsProvider);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                DateFormat('d MMM, h:mm a').format(reading.takenAt),
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),
            Expanded(
              child: Text(
                '${reading.display} ${reading.unit}',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (level != null)
              _LevelChip(level: level.level, label: level.label),
          ],
        ),
      ),
    );
  }
}

/// Log a reading: big number fields, and for sugar, when it was taken.
class AddReadingSheet extends ConsumerStatefulWidget {
  const AddReadingSheet({super.key, required this.kind});

  final ReadingKind kind;

  @override
  ConsumerState<AddReadingSheet> createState() => _AddReadingSheetState();
}

class _AddReadingSheetState extends ConsumerState<AddReadingSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String _context = 'fasting';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  bool get _valid {
    final a = _num(_a);
    return switch (widget.kind) {
      ReadingKind.bp =>
        a != null &&
            a >= 50 &&
            a <= 260 &&
            (_num(_b) ?? 0) >= 30 &&
            (_num(_b) ?? 0) <= 180,
      ReadingKind.sugar => a != null && a >= 1 && a <= 40,
      ReadingKind.weight => a != null && a >= 2 && a <= 350,
    };
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .addReading(
            kind: widget.kind.name,
            value: _num(_a)!,
            value2: widget.kind == ReadingKind.bp ? _num(_b) : null,
            context: widget.kind == ReadingKind.sugar ? _context : null,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String hint, String suffix) =>
      TextField(
        controller: c,
        autofocus: c == _a,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        decoration: InputDecoration(hintText: hint, suffixText: suffix),
        onChanged: (_) => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Log ${widget.kind.label.toLowerCase()}',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          switch (widget.kind) {
            ReadingKind.bp => Row(
              children: [
                Expanded(child: _field(_a, '120', '')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('/', style: text.headlineMedium),
                ),
                Expanded(child: _field(_b, '80', '')),
              ],
            ),
            ReadingKind.sugar => _field(_a, '5.4', 'mmol/L'),
            ReadingKind.weight => _field(_a, '70', 'kg'),
          },
          if (widget.kind == ReadingKind.bp)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Top number / bottom number (mmHg)',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ),
          if (widget.kind == ReadingKind.sugar) ...[
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                for (final (v, l) in const [
                  ('fasting', 'Before eating'),
                  ('after_meal', 'After a meal'),
                  ('random', 'Any time'),
                ])
                  ChoiceChip(
                    label: Text(l),
                    selected: _context == v,
                    onSelected: (_) => setState(() => _context = v),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
