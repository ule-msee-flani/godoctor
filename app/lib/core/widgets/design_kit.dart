import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../utils/format.dart';

/// A row of days to swipe through: weekday, big date, and how many slots
/// (days with none are greyed out). The chosen day becomes a filled pill.
class DateScroller extends StatelessWidget {
  const DateScroller({
    super.key,
    required this.days,
    required this.selected,
    required this.onSelected,
    this.counts,
  });

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  /// Open slots per day; when given, days with none can't be picked.
  final Map<DateTime, int>? counts;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final today = DateUtils.dateOnly(DateTime.now());
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final on = selected != null && DateUtils.isSameDay(d, selected);
          final n = counts?[DateUtils.dateOnly(d)];
          final open = counts == null || (n ?? 0) > 0;
          final fg = on
              ? Colors.white
              : open
              ? AppColors.ink
              : AppColors.inkFaint;
          return Semantics(
            button: true,
            selected: on,
            label: DateFormat('EEEE d MMMM').format(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 62,
              decoration: BoxDecoration(
                color: on
                    ? AppColors.primary
                    : open
                    ? AppColors.white
                    : AppColors.primarySofter,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: on ? AppColors.primary : AppColors.border,
                ),
                boxShadow: on
                    ? const [
                        BoxShadow(
                          color: Color(0x331B63F2),
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: open ? () => onSelected(DateUtils.dateOnly(d)) : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateUtils.isSameDay(d, today)
                            ? 'Today'
                            : DateFormat('EEE').format(d),
                        style: text.labelSmall?.copyWith(
                          color: on ? Colors.white70 : AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      if (counts != null)
                        Text(
                          (n ?? 0) == 0 ? '—' : '$n free',
                          style: text.labelSmall?.copyWith(
                            fontSize: 10,
                            color: on
                                ? Colors.white
                                : open
                                ? AppColors.success
                                : AppColors.inkFaint,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

/// A photo that melts into its card: faded towards the left and the
/// bottom, so a normal photo sits in a pastel card like a cut-out.
class FadedPhoto extends StatelessWidget {
  const FadedPhoto({
    super.key,
    required this.url,
    required this.name,
    this.alignment = const Alignment(0, -0.4),
  });

  final String? url;

  /// For the initials when there's no photo.
  final String name;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final initials = Center(
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
    );
    if (url == null) return initials;
    Shader fade(Rect r, Alignment from, Alignment to) => LinearGradient(
      begin: from,
      end: to,
      colors: const [Colors.transparent, Colors.black],
      stops: const [0, 0.45],
    ).createShader(r);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => fade(r, Alignment.centerLeft, Alignment.centerRight),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => fade(
          r,
          Alignment.bottomCenter,
          Alignment.topCenter,
        ),
        child: Image.network(
          url!,
          fit: BoxFit.cover,
          alignment: alignment,
          errorBuilder: (_, _, _) => initials,
        ),
      ),
    );
  }
}

/// "10y+ / Experience" — a big number over a small label on a pastel tile.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.value,
    required this.label,
    this.gradient = AppColors.skyGradient,
    this.icon,
  });

  final String value;
  final String label;
  final Gradient gradient;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: AppColors.ink),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional "see all" arrow.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.onMore, this.padding});

  final String title;
  final VoidCallback? onMore;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (onMore != null)
            IconButton(
              tooltip: 'See all',
              visualDensity: VisualDensity.compact,
              onPressed: onMore,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
        ],
      ),
    );
  }
}
