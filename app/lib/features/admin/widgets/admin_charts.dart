import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import 'admin_ui.dart';

/// One day's value in a time series.
class SeriesPoint {
  const SeriesPoint(this.day, this.value);

  final DateTime day;
  final num value;
}

enum SeriesForm { area, columns }

/// A single-series trend card: area line (money, continuous) or columns
/// (daily counts). One hue, hairline grid, crosshair/bar tooltips, and a
/// table view for every value.
class TimeSeriesCard extends StatefulWidget {
  const TimeSeriesCard({
    super.key,
    required this.title,
    required this.points,
    required this.form,
    this.valueFormat = compactNumber,
    this.headline,
    this.height = 210,
  });

  final String title;
  final List<SeriesPoint> points;
  final SeriesForm form;
  final String Function(num) valueFormat;

  /// Shown beside the title, e.g. the period total.
  final String? headline;
  final double height;

  @override
  State<TimeSeriesCard> createState() => _TimeSeriesCardState();
}

class _TimeSeriesCardState extends State<TimeSeriesCard> {
  bool _table = false;

  static final _dayFmt = DateFormat('d MMM');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AdminCard(
      title: widget.title,
      subtitle: widget.headline,
      trailing: IconButton(
        tooltip: _table ? 'Show chart' : 'Show as table',
        visualDensity: VisualDensity.compact,
        icon: Icon(
          _table ? LucideIcons.chartLine : LucideIcons.table,
          size: 18,
        ),
        onPressed: () => setState(() => _table = !_table),
      ),
      child: SizedBox(
        // Includes the x-axis label band, so nothing scrolls inside.
        height: widget.height,
        child: widget.points.isEmpty
            ? Center(child: Text('No data', style: theme.bodySmall))
            : _table
            ? _TableView(points: widget.points, format: widget.valueFormat)
            : widget.form == SeriesForm.area
            ? _area(context)
            : _columns(context),
      ),
    );
  }

  double _maxY() {
    final m = widget.points.map((p) => p.value.toDouble()).fold(0.0, math.max);
    return _niceCeil(m <= 0 ? 1 : m);
  }

  FlTitlesData _titles(BuildContext context, double maxY) {
    final n = widget.points.length;
    final every = math.max(1, (n / 6).ceil());
    final small = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AdminColors.muted);
    return FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          interval: maxY / 4,
          getTitlesWidget: (v, meta) => SideTitleWidget(
            meta: meta,
            child: Text(widget.valueFormat(v), style: small),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          interval: 1,
          getTitlesWidget: (v, meta) {
            final i = v.round();
            if (i < 0 || i >= n || (n - 1 - i) % every != 0) {
              return const SizedBox.shrink();
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(_dayFmt.format(widget.points[i].day), style: small),
            );
          },
        ),
      ),
    );
  }

  FlGridData _grid(double maxY) => FlGridData(
    drawVerticalLine: false,
    horizontalInterval: maxY / 4,
    getDrawingHorizontalLine: (_) =>
        const FlLine(color: AdminColors.grid, strokeWidth: 1),
  );

  FlBorderData get _border => FlBorderData(
    show: true,
    border: const Border(bottom: BorderSide(color: AdminColors.axis)),
  );

  Widget _area(BuildContext context) {
    final maxY = _maxY();
    final pts = widget.points;
    final last = pts.length - 1;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: last.toDouble(),
        gridData: _grid(maxY),
        borderData: _border,
        titlesData: _titles(context, maxY),
        lineTouchData: LineTouchData(
          getTouchedSpotIndicator: (bar, idx) => [
            for (final _ in idx)
              TouchedSpotIndicatorData(
                const FlLine(color: AdminColors.axis, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: AdminColors.series1,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.ink,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${widget.valueFormat(s.y)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: _dayFmt.format(pts[s.x.round()].day),
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
          LineChartBarData(
            spots: [
              for (var i = 0; i < pts.length; i++)
                FlSpot(i.toDouble(), pts[i].value.toDouble()),
            ],
            color: AdminColors.series1,
            barWidth: 2,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            belowBarData: BarAreaData(
              show: true,
              color: AdminColors.series1.withValues(alpha: 0.1),
            ),
            // End-dot on the latest value only.
            dotData: FlDotData(
              checkToShowDot: (spot, _) => spot.x == last,
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: AdminColors.series1,
                strokeWidth: 2,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _columns(BuildContext context) {
    final maxY = _maxY();
    final pts = widget.points;
    return LayoutBuilder(
      builder: (context, c) {
        final slot = (c.maxWidth - 46) / pts.length;
        final width = (slot * 0.6).clamp(2.0, 24.0);
        return BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: _grid(maxY),
            borderData: _border,
            titlesData: _titles(context, maxY),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => AppColors.ink,
                fitInsideHorizontally: true,
                getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                  '${widget.valueFormat(rod.toY)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  children: [
                    TextSpan(
                      text: _dayFmt.format(pts[group.x].day),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            barGroups: [
              for (var i = 0; i < pts.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: pts[i].value.toDouble(),
                      width: width,
                      color: AdminColors.series1,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 0 / clean round number above [v] for the y-axis top.
double _niceCeil(double v) {
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (m * exp >= v) return m * exp;
  }
  return 10 * exp;
}

class _TableView extends StatelessWidget {
  const _TableView({required this.points, required this.format});

  final List<SeriesPoint> points;
  final String Function(num) format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final rows = points.reversed.toList();
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEE d MMM').format(rows[i].day),
                style: theme.bodySmall,
              ),
            ),
            Text(
              format(rows[i].value),
              style: theme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Part-to-whole as one horizontal stacked bar (2px gaps between
/// segments) plus a legend that also carries every value, so identity and
/// numbers never rely on colour alone.
class StackedShareBar extends StatelessWidget {
  const StackedShareBar({super.key, required this.segments});

  final List<(String label, num value, Color color)> segments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = segments.fold<num>(0, (s, e) => s + e.$2);
    final visible = segments.where((s) => s.$2 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 16,
            child: total == 0
                ? const ColoredBox(color: AdminColors.grid)
                : Row(
                    children: [
                      for (var i = 0; i < visible.length; i++) ...[
                        if (i > 0) const SizedBox(width: 2),
                        Expanded(
                          flex: math.max(
                            1,
                            (visible[i].$2 / total * 1000).round(),
                          ),
                          child: Tooltip(
                            message:
                                '${visible[i].$1}: ${compactNumber(visible[i].$2)}',
                            child: ColoredBox(color: visible[i].$3),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.$3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(s.$1, style: theme.bodySmall),
                  const SizedBox(width: 4),
                  Text(
                    '${compactNumber(s.$2)}'
                    '${total == 0 ? '' : ' · ${(s.$2 / total * 100).toStringAsFixed(0)}%'}',
                    style: theme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Magnitudes as thin horizontal bars in one hue, value at the tip.
class BarList extends StatelessWidget {
  const BarList({
    super.key,
    required this.items,
    this.valueFormat = compactNumber,
    this.emptyMessage = 'No data yet',
  });

  final List<(String label, num value)> items;
  final String Function(num) valueFormat;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (items.isEmpty) {
      return Text(emptyMessage, style: theme.bodySmall);
    }
    final max = items.map((e) => e.$2).fold<num>(0, math.max);
    return Column(
      children: [
        for (final (label, value) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: AppColors.ink),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: max == 0
                              ? 0.01
                              : (value / max).clamp(0.01, 1.0).toDouble(),
                          child: Container(
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AdminColors.series1,
                              borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        valueFormat(value),
                        style: theme.bodySmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
