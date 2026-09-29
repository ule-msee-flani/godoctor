import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';

/// "The details I've given are genuine" — ticked before a doctor or
/// pharmacy can submit their registration.
class DeclarationTile extends StatelessWidget {
  const DeclarationTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.regulator,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  /// Who false details may be reported to, e.g. "the KMPDC".
  final String regulator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: value ? AppColors.successSoft : AppColors.primarySofter,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: value ? AppColors.success : AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'I confirm my details are genuine',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'The information and documents I\'ve given are true and my own. '
              'I understand that false details will get my account removed and '
              'may be reported to $regulator.',
              style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

/// A last check before sending the registration for review.
Future<bool> confirmSubmission(
  BuildContext context, {
  required String checking,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(LucideIcons.shieldCheck, color: AppColors.primary),
      title: const Text('Submit for verification?'),
      content: Text(
        'Our team will check $checking. This can take a few working days; '
        'we\'ll email you and send a notification as soon as you\'re '
        'approved.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Check again'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Yes, submit'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
