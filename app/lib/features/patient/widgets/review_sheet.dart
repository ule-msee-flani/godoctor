import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

final hasReviewedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(appointmentRepositoryProvider).hasReviewed(id),
);

/// My stars for a consultation (null until I rate it).
final myVisitRatingProvider = FutureProvider.autoDispose.family<int?, String>(
  (ref, id) => ref.watch(appointmentRepositoryProvider).myRating(id),
);

/// "Rate your doctor" button for a completed consultation, or a confirmation
/// once the patient has reviewed it. Renders nothing while loading.
class ReviewPrompt extends ConsumerWidget {
  const ReviewPrompt({
    super.key,
    required this.consultationId,
    required this.doctorName,
  });

  final String consultationId;
  final String doctorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewed = ref.watch(hasReviewedProvider(consultationId)).valueOrNull;
    if (reviewed == null) return const SizedBox.shrink();
    if (reviewed) {
      return const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.badgeCheck, size: 16, color: AppColors.success),
          SizedBox(width: 6),
          Text('You reviewed this consultation'),
        ],
      );
    }
    return OutlinedButton.icon(
      icon: const Icon(LucideIcons.star, size: 18),
      label: const Text('Rate your doctor'),
      onPressed: () async {
        final done = await showReviewSheet(
          context,
          consultationId: consultationId,
          doctorName: doctorName,
        );
        if (done) {
          ref.invalidate(hasReviewedProvider(consultationId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanks for your review')),
            );
          }
        }
      },
    );
  }
}

/// Rate a completed consultation. Returns true if a review was submitted.
/// The server only accepts a review from the patient of a completed
/// consultation, once. [extra] adds a link under the button (e.g. "See the
/// visit summary").
Future<bool> showReviewSheet(
  BuildContext context, {
  required String consultationId,
  required String doctorName,
  int initialRating = 0,
  ({String label, VoidCallback onTap})? extra,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return _showRateSheet(
    context,
    title: 'How was your visit?',
    subject: 'with $doctorName',
    tags: const [
      'Listened well',
      'Explained clearly',
      'On time',
      'Friendly',
      'Thorough',
    ],
    initialRating: initialRating,
    extra: extra,
    submit: (rating, comment) => container
        .read(appointmentRepositoryProvider)
        .submitReview(
          consultationId: consultationId,
          rating: rating,
          comment: comment,
        ),
  );
}

/// Rate the pharmacy after a completed order. Returns true if submitted.
Future<bool> showPharmacyReviewSheet(
  BuildContext context, {
  required String orderId,
  required String pharmacyName,
  int initialRating = 0,
}) {
  final container = ProviderScope.containerOf(context, listen: false);
  return _showRateSheet(
    context,
    title: 'How was your order?',
    subject: 'from $pharmacyName',
    tags: const [
      'Quick service',
      'Helpful pharmacist',
      'Well packed',
      'Fair prices',
      'Easy to find',
    ],
    initialRating: initialRating,
    submit: (rating, comment) => container
        .read(orderRepositoryProvider)
        .reviewPharmacy(orderId: orderId, rating: rating, comment: comment),
  );
}

Future<bool> _showRateSheet(
  BuildContext context, {
  required String title,
  required String subject,
  required List<String> tags,
  required Future<void> Function(int rating, String? comment) submit,
  int initialRating = 0,
  ({String label, VoidCallback onTap})? extra,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _RateSheet(
        title: title,
        subject: subject,
        tags: tags,
        submit: submit,
        initialRating: initialRating,
        extra: extra,
      ),
    ),
  );
  return submitted ?? false;
}

class _RateSheet extends StatefulWidget {
  const _RateSheet({
    required this.title,
    required this.subject,
    required this.tags,
    required this.submit,
    required this.initialRating,
    this.extra,
  });

  final String title;
  final String subject;
  final List<String> tags;
  final Future<void> Function(int rating, String? comment) submit;
  final int initialRating;
  final ({String label, VoidCallback onTap})? extra;

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  late int _rating = widget.initialRating.clamp(0, 5);
  final _picked = <String>{};
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// "Quick service · Well packed. The rest of what they typed."
  String? get _comment {
    final chosen = [
      for (final t in widget.tags)
        if (_picked.contains(t)) t,
    ].join(' · ');
    final typed = _commentCtrl.text.trim();
    final all = [
      if (chosen.isNotEmpty) chosen,
      if (typed.isNotEmpty) typed,
    ].join('. ');
    return all.isEmpty ? null : all;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit(_rating, _comment);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: theme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.subject,
              style: theme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    iconSize: 40,
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = i);
                    },
                    icon: AnimatedScale(
                      duration: const Duration(milliseconds: 160),
                      scale: i == _rating ? 1.18 : 1,
                      child: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i <= _rating
                            ? AppColors.warning
                            : AppColors.borderStrong,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(
              height: 22,
              child: Text(
                _labels[_rating],
                textAlign: TextAlign.center,
                style: theme.titleSmall?.copyWith(color: AppColors.warning),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in widget.tags)
                  FilterChip(
                    label: Text(t),
                    selected: _picked.contains(t),
                    onSelected: (on) =>
                        setState(() => on ? _picked.add(t) : _picked.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 400,
              decoration: const InputDecoration(
                hintText:
                    'Anything else? (optional) Reviews are shown without your name.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _rating == 0 || _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit review'),
            ),
            if (widget.extra != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  widget.extra!.onTap();
                },
                child: Text(widget.extra!.label),
              ),
          ],
        ),
      ),
    );
  }
}

/// "How was it?" with five stars to tap right there; a tap opens the full
/// review sheet with that many stars. Once rated it thanks the patient.
class InlineRateCard extends StatelessWidget {
  const InlineRateCard({
    super.key,
    required this.question,
    required this.onPick,
    this.rated,
  });

  final String question;

  /// The stars already given, if any.
  final int? rated;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final done = rated != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: done ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            done ? 'Thanks for your review' : question,
            textAlign: TextAlign.center,
            style: theme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                done
                    ? Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          i <= rated!
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 26,
                          color: AppColors.warning,
                        ),
                      )
                    : IconButton(
                        tooltip: 'Rate $i',
                        iconSize: 34,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onPick(i),
                        icon: const Icon(
                          Icons.star_outline_rounded,
                          color: AppColors.warning,
                        ),
                      ),
            ],
          ),
          if (!done)
            Text(
              'Your review helps other patients choose.',
              style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
        ],
      ),
    );
  }
}

/// The rate card for a completed visit (hidden while loading).
class DoctorRateCard extends ConsumerWidget {
  const DoctorRateCard({
    super.key,
    required this.consultationId,
    required this.doctorName,
  });

  final String consultationId;
  final String doctorName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myVisitRatingProvider(consultationId));
    if (!async.hasValue) return const SizedBox.shrink();
    return InlineRateCard(
      question: 'How was your visit with $doctorName?',
      rated: async.value,
      onPick: (stars) async {
        final done = await showReviewSheet(
          context,
          consultationId: consultationId,
          doctorName: doctorName,
          initialRating: stars,
        );
        if (done) {
          ref.invalidate(myVisitRatingProvider(consultationId));
          ref.invalidate(hasReviewedProvider(consultationId));
        }
      },
    );
  }
}
