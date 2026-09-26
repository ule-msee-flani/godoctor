import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

/// What the patient told us in step 1, carried into steps 2 and 3.
class ConsultDraft {
  const ConsultDraft({required this.specialty, required this.symptoms});

  final String specialty;
  final String symptoms;
}

/// The in-progress "See a doctor" request (null until step 1 is done).
final consultDraftProvider = StateProvider<ConsultDraft?>((ref) => null);

/// "1 Describe · 2 Choose doctor · 3 Pay & see" header shown on each step.
class ConsultSteps extends StatelessWidget {
  const ConsultSteps({super.key, required this.current});

  /// 1, 2 or 3.
  final int current;

  static const _labels = ['Describe', 'Choose doctor', 'Pay & see'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Semantics(
      label: 'Step $current of 3: ${_labels[current - 1]}',
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            _Dot(step: i, current: current),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _labels[i - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(
                  color: i <= current ? AppColors.ink : AppColors.inkFaint,
                  fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (i < 3)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: i < current ? AppColors.primary : AppColors.border,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.step, required this.current});

  final int step;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = step < current;
    final active = step == current;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done || active ? AppColors.primary : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: done || active ? AppColors.primary : AppColors.borderStrong,
          width: 1.5,
        ),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.inkFaint,
                ),
              ),
      ),
    );
  }
}
