import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading_view.dart';
import '../../data/models/public_doctor.dart';
import '../../data/repositories/repository_errors.dart';
import '../patient/widgets/doctor_widgets.dart' show RatingStars;

/// "What patients say" on a doctor's or pharmacy's profile: the average
/// rating with a bar per star, then each review.
class ReviewsBlock extends StatelessWidget {
  const ReviewsBlock({
    super.key,
    required this.reviews,
    required this.average,
    required this.count,
    required this.emptyText,
  });

  final AsyncValue<List<DoctorReview>> reviews;
  final double average;
  final int count;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return reviews.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LoadingView(),
      ),
      error: (e, _) => Text(friendlyError(e)),
      data: (list) {
        if (list.isEmpty) {
          return Text(emptyText, style: Theme.of(context).textTheme.bodyMedium);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RatingSummary(average: average, count: count, reviews: list),
            const SizedBox(height: 12),
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ReviewCard(review: r),
              ),
          ],
        );
      },
    );
  }
}

/// "4.8 ★ · 23 reviews" with a bar for each star count.
class RatingSummary extends StatelessWidget {
  const RatingSummary({
    super.key,
    required this.average,
    required this.count,
    required this.reviews,
  });

  final double average;
  final int count;
  final List<DoctorReview> reviews;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final total = reviews.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySofter,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                average.toStringAsFixed(1),
                style: theme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              RatingStars(rating: average, size: 14),
              const SizedBox(height: 4),
              Text(
                count == 1 ? '1 review' : '$count reviews',
                style: theme.bodySmall,
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 12,
                          child: Text('$star', style: theme.bodySmall),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0
                                  ? 0
                                  : reviews
                                            .where((r) => r.rating == star)
                                            .length /
                                        total,
                              minHeight: 6,
                              backgroundColor: AppColors.border,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final DoctorReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RatingStars(rating: review.rating.toDouble(), size: 15),
                const Spacer(),
                Text(formatDayShort(review.createdAt), style: theme.bodySmall),
              ],
            ),
            if ((review.comment ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment!, style: theme.bodyMedium),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  LucideIcons.badgeCheck,
                  size: 13,
                  color: AppColors.ink,
                ),
                const SizedBox(width: 4),
                Text('Verified patient', style: theme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
