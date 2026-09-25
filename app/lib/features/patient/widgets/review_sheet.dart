import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';

final hasReviewedProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, id) => ref.watch(appointmentRepositoryProvider).hasReviewed(id),
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

/// Bottom sheet to rate a completed consultation. Returns true if a review
/// was submitted. The server only accepts a review from the patient of a
/// completed consultation, once.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String consultationId,
  required String doctorName,
}) async {
  final submitted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _ReviewSheet(
        consultationId: consultationId,
        doctorName: doctorName,
      ),
    ),
  );
  return submitted ?? false;
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.consultationId, required this.doctorName});

  final String consultationId;
  final String doctorName;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 0;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(appointmentRepositoryProvider)
          .submitReview(
            consultationId: widget.consultationId,
            rating: _rating,
            comment: _commentCtrl.text.trim(),
          );
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
              'How was your consultation?',
              style: theme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'with ${widget.doctorName}',
              style: theme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    iconSize: 38,
                    onPressed: () => setState(() => _rating = i),
                    icon: Icon(
                      LucideIcons.star,
                      color: i <= _rating
                          ? AppColors.warning
                          : AppColors.borderStrong,
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
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText:
                    'Add a comment (optional). Reviews are shown without your name.',
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
          ],
        ),
      ),
    );
  }
}
