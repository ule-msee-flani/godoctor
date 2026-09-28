import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';

/// Chart + chrome colours for the admin console. Categorical slots follow
/// the validated reference order (blue, orange, aqua, yellow -- adjacent
/// CVD dE >= 9.1 on white); the lighter two need visible labels, which
/// every chart here shows.
abstract final class AdminColors {
  static const series1 = Color(0xFF2A78D6);
  static const series2 = Color(0xFFEB6834);
  static const series3 = Color(0xFF1BAF7A);
  static const series4 = Color(0xFFEDA100);
  static const categorical = [series1, series2, series3, series4];

  static const grid = Color(0xFFE1E0D9);
  static const axis = Color(0xFFC3C2B7);
  static const muted = Color(0xFF898781);
  static const page = Color(0xFFF6F7FB);
  static const sidebar = Color(0xFF0B1730);
  static const sidebarActive = Color(0xFF1B2B52);

  // Status (always shown with an icon + label, never colour alone).
  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFC98500);
  static const critical = Color(0xFFD03B3B);
}

// ---------------------------------------------------------------------------
// Formatting
// ---------------------------------------------------------------------------

final _compact = NumberFormat.compact();
final _grouped = NumberFormat.decimalPattern();

/// 1,284 / 12.9K / 4.2M
String compactNumber(num n) =>
    n.abs() < 10000 ? _grouped.format(n) : _compact.format(n);

String kes(num n) => 'KES ${compactNumber(n.round())}';

String bytes(num b) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// "just now", "4 min ago", "3 h ago", "12 Sep"
String ago(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  return DateFormat('d MMM yyyy').format(t.toLocal());
}

String stamp(DateTime? t) =>
    t == null ? '—' : DateFormat('d MMM, HH:mm').format(t.toLocal());

DateTime? parseTime(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

num asNum(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

String shortId(Object? id) {
  final s = '${id ?? ''}';
  return s.length > 8 ? s.substring(0, 8) : s;
}

/// "in_progress" -> "In progress"
String humanize(Object? v) {
  final s = '${v ?? ''}'.replaceAll('_', ' ');
  return s.isEmpty ? '—' : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Page frame
// ---------------------------------------------------------------------------

/// Title row + content for one console page.
class AdminPage extends StatelessWidget {
  const AdminPage({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.actions = const [],
    this.onRefresh,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: theme.headlineSmall),
                if (subtitle != null) Text(subtitle!, style: theme.bodyMedium),
              ],
            ),
            if (actions.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 18),
        ...children,
      ],
    );
    return ColoredBox(
      color: AdminColors.page,
      child: onRefresh == null
          ? list
          : LiveRefresh(onRefresh: onRefresh!, child: list),
    );
  }
}

class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    // A Material surface (not a decorated box) so list tiles and ink
    // splashes inside the card draw correctly.
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title!, style: theme.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: theme.bodySmall),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Lays children out in as many equal columns as fit ([minWidth] each).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minWidth = 220,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double minWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minWidth).floor().clamp(1, 6);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Figures
// ---------------------------------------------------------------------------

/// label · value · optional delta vs the previous period.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.current,
    this.previous,
    this.upIsGood = true,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// For the delta: this period vs the one before.
  final num? current;
  final num? previous;
  final bool upIsGood;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    Widget? delta;
    if (current != null && previous != null) {
      final diff = current! - previous!;
      final good = diff == 0 ? null : (diff > 0) == upIsGood;
      final pct = previous == 0
          ? (current == 0 ? '0%' : 'new')
          : '${(diff / previous! * 100).abs().toStringAsFixed(0)}%';
      final color = good == null
          ? AdminColors.muted
          : (good ? const Color(0xFF006300) : AdminColors.critical);
      delta = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diff > 0
                ? LucideIcons.trendingUp
                : diff < 0
                ? LucideIcons.trendingDown
                : LucideIcons.minus,
            size: 14,
            color: AppColors.ink,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              diff == 0 ? 'no change' : '$pct vs previous',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                  Icon(icon, size: 18, color: AppColors.inkFaint),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: theme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              ?delta,
              if (caption != null)
                Text(
                  caption!,
                  style: theme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Tone { good, warning, critical, info, neutral }

/// A status label: icon + text + tint (never colour alone).
class StatusChip extends StatelessWidget {
  const StatusChip(this.text, {super.key, this.tone = Tone.neutral});

  final String text;
  final Tone tone;

  /// Picks a tone from common status words.
  factory StatusChip.auto(Object? status, {Key? key}) {
    final s = '${status ?? ''}';
    final tone = switch (s) {
      'active' ||
      'completed' ||
      'fulfilled' ||
      'succeeded' ||
      'released' ||
      'answered' ||
      'accepted' ||
      'joined' ||
      'verified' => Tone.good,
      'in_progress' ||
      'matched' ||
      'confirmed' ||
      'ready' ||
      'held' ||
      'scheduled' ||
      'open' => Tone.info,
      'awaiting_payment' ||
      'placed' ||
      'pending' ||
      'searching' ||
      'invited' => Tone.warning,
      'suspended' ||
      'cancelled' ||
      'expired' ||
      'failed' ||
      'disputed' ||
      'refunded' ||
      'declined' => Tone.critical,
      _ => Tone.neutral,
    };
    return StatusChip(humanize(s), key: key, tone: tone);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      Tone.good => (AdminColors.good, LucideIcons.circleCheck),
      Tone.warning => (AdminColors.warning, LucideIcons.clock3),
      Tone.critical => (AdminColors.critical, LucideIcons.circleX),
      Tone.info => (AppColors.primary, LucideIcons.circleDot),
      Tone.neutral => (AppColors.inkSoft, LucideIcons.circle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data table
// ---------------------------------------------------------------------------

class AdminColumn {
  const AdminColumn(
    this.label,
    this.cell, {
    this.width = 140,
    this.numeric = false,
  });

  final String label;
  final Widget Function(Map<String, dynamic> row) cell;
  final double width;
  final bool numeric;
}

/// A dense, horizontally scrollable table with a pager. While a new page
/// loads, the previous rows stay visible (dimmed) instead of flashing.
class AdminTable extends StatelessWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.total,
    this.page = 0,
    this.pageSize = 50,
    this.onPage,
    this.onTapRow,
    this.loading = false,
    this.emptyMessage = 'Nothing here yet.',
  });

  final List<AdminColumn> columns;
  final List<Map<String, dynamic>> rows;
  final int? total;
  final int page;
  final int pageSize;
  final ValueChanged<int>? onPage;
  final ValueChanged<Map<String, dynamic>>? onTapRow;
  final bool loading;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final width = columns.fold<double>(0, (s, c) => s + c.width) + 32;
    final pages = total == null
        ? null
        : (total! / pageSize).ceil().clamp(1, 1 << 30);

    Widget cell(AdminColumn c, Widget child) => SizedBox(
      width: c.width,
      child: Align(
        alignment: c.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: child,
        ),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedOpacity(
            opacity: loading ? 0.5 : 1,
            duration: const Duration(milliseconds: 150),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: AdminColors.page,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          for (final c in columns)
                            cell(
                              c,
                              Text(
                                c.label.toUpperCase(),
                                style: theme.labelSmall?.copyWith(
                                  color: AppColors.inkSoft,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (rows.isEmpty && !loading)
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(emptyMessage, style: theme.bodyMedium),
                      ),
                    for (var i = 0; i < rows.length; i++)
                      InkWell(
                        onTap: onTapRow == null
                            ? null
                            : () => onTapRow!(rows[i]),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              for (final c in columns) cell(c, c.cell(rows[i])),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (onPage != null && pages != null)
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      total == 0
                          ? 'No results'
                          : '${page * pageSize + 1}–${(page * pageSize + rows.length)} of ${compactNumber(total!)}',
                      style: theme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous page',
                    onPressed: page > 0 ? () => onPage!(page - 1) : null,
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  Text('${page + 1} / $pages', style: theme.bodySmall),
                  IconButton(
                    tooltip: 'Next page',
                    onPressed: page + 1 < pages
                        ? () => onPage!(page + 1)
                        : null,
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Two-line cell: bold primary text + small secondary.
class TwoLine extends StatelessWidget {
  const TwoLine(this.primary, [this.secondary, Key? key]) : super(key: key);

  final String primary;
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodyMedium?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (secondary != null)
          Text(
            secondary!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall,
          ),
      ],
    );
  }
}

/// Single-line table text with tabular figures for numbers.
class CellText extends StatelessWidget {
  const CellText(this.text, {super.key, this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: AppColors.ink,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontFamily: mono ? 'monospace' : null,
      fontSize: mono ? 12.5 : null,
    ),
  );
}

/// Choice chips in a row, for table filters. `null` value = "All".
class FilterRow<T> extends StatelessWidget {
  const FilterRow({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.allLabel = 'All',
  });

  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String allLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: Text(allLabel),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final (v, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: value == v,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}

/// Search box for list pages (submits after typing stops).
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.onSubmitted,
    this.hint = 'Search',
  });

  final ValueChanged<String> onSubmitted;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: TextField(
        onSubmitted: onSubmitted,
        onChanged: (v) {
          if (v.isEmpty) onSubmitted('');
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          prefixIcon: const Icon(LucideIcons.search, size: 18),
        ),
      ),
    );
  }
}

Widget adminError(Object e, VoidCallback retry) =>
    ErrorView(message: friendlyError(e), onRetry: retry);
