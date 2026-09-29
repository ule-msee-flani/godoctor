import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import 'package:intl/intl.dart';

/// Doctor photo with an initials fallback (no photo set, or it failed to load).
class DoctorAvatar extends ConsumerWidget {
  const DoctorAvatar({
    super.key,
    required this.name,
    this.avatarPath,
    this.radius = 28,
  });

  final String name;
  final String? avatarPath;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref
        .watch(doctorDirectoryRepositoryProvider)
        .avatarUrl(avatarPath);

    Widget fallback() => CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );

    if (url == null) return fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
}

/// Five stars showing [rating] (0-5), rounded to the nearest half is not
/// needed: whole-star fill is clearer at small sizes.
class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            LucideIcons.star,
            size: size,
            color: i <= rating.round()
                ? AppColors.warning
                : AppColors.borderStrong,
          ),
      ],
    );
  }
}

/// "4.8 (32)" or "No reviews yet".
class RatingSummary extends StatelessWidget {
  const RatingSummary({super.key, required this.doctor});

  final PublicDoctor doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    if (doctor.ratingCount == 0) {
      return Text('No reviews yet', style: theme.bodySmall);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.star, size: 14, color: AppColors.warning),
        const SizedBox(width: 4),
        Text(doctor.ratingAvg.toStringAsFixed(1), style: theme.titleSmall),
        const SizedBox(width: 4),
        Text('(${doctor.ratingCount})', style: theme.bodySmall),
      ],
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Licence verified',
    child: Icon(LucideIcons.badgeCheck, size: size, color: AppColors.ink),
  );
}

/// One directory row.
class DoctorCard extends StatelessWidget {
  const DoctorCard({super.key, required this.doctor, this.onTap, this.slots});

  final PublicDoctor doctor;

  /// Open appointment slots per day (from today); shows the day strip when
  /// given.
  final Map<DateTime, int>? slots;

  /// Defaults to opening the doctor's public profile.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final available = doctor.availableNow;
    final next = doctor.nextSlot;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap ?? () => context.push('/patient/doctor/${doctor.userId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DoctorAvatar(
                    name: doctor.name,
                    avatarPath: doctor.avatarPath,
                    radius: 30,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                doctor.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.titleSmall,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const VerifiedBadge(),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          doctor.specialties.isEmpty
                              ? 'General Practice'
                              : doctor.specialties.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            RatingSummary(doctor: doctor),
                            if (doctor.yearsExperience != null)
                              Text(
                                '${doctor.yearsExperience} yrs',
                                style: theme.bodySmall,
                              ),
                            Text(
                              formatKes(doctor.consultationFee),
                              style: theme.bodySmall?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _AvailabilityPill(available: available, next: next),
                      ],
                    ),
                  ),
                ],
              ),
              if (slots != null) ...[
                const SizedBox(height: 12),
                SlotStrip(doctorId: doctor.userId, slots: slots!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today 3 slots · Tomorrow 5 slots · Thu 2 · ..." — tap a day with slots
/// to book.
class SlotStrip extends StatelessWidget {
  const SlotStrip({
    super.key,
    required this.doctorId,
    required this.slots,
    this.days = 4,
  });

  final String doctorId;
  final Map<DateTime, int> slots;
  final int days;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Row(
      children: [
        for (var i = 0; i < days; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _DayChip(
              label: switch (i) {
                0 => 'Today',
                1 => 'Tomorrow',
                _ => DateFormat('EEE d').format(today.add(Duration(days: i))),
              },
              count: slots[today.add(Duration(days: i))] ?? 0,
              onTap: () => context.push('/patient/book/$doctorId'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = count > 0;
    return Material(
      color: open ? AppColors.primarySoft : AppColors.primarySofter,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: text.labelMedium?.copyWith(
                  color: open ? AppColors.ink : AppColors.inkFaint,
                ),
              ),
              Text(
                open ? '$count ${count == 1 ? 'slot' : 'slots'}' : 'None',
                maxLines: 1,
                style: text.labelSmall?.copyWith(
                  color: open ? AppColors.primary : AppColors.inkFaint,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.available, required this.next});

  final bool available;
  final DateTime? next;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final Color fg;
    final IconData icon;

    if (available) {
      label = 'Available now';
      bg = AppColors.successSoft;
      fg = AppColors.success;
      icon = LucideIcons.zap;
    } else if (next != null) {
      label = 'Next: ${formatRelativeSlot(next!)}';
      bg = AppColors.primarySoft;
      fg = AppColors.primary;
      icon = LucideIcons.calendarClock;
    } else {
      label = 'No open slots';
      bg = AppColors.border;
      fg = AppColors.inkSoft;
      icon = LucideIcons.calendarX;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
