import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/repository_providers.dart';
import '../../data/repositories/repository_errors.dart';

/// "Rate GoDoctor": 1-5 stars and an optional comment. Rating again
/// replaces the earlier one.
Future<void> showRateAppSheet(BuildContext context) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => const _RateSheet(),
);

class _RateSheet extends ConsumerStatefulWidget {
  const _RateSheet();

  @override
  ConsumerState<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<_RateSheet> {
  final _comment = TextEditingController();
  int _stars = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref
        .read(supportRepositoryProvider)
        .myRating()
        .then((r) {
          if (r != null && mounted) {
            setState(() {
              _stars = r.stars;
              _comment.text = r.comment ?? '';
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(supportRepositoryProvider)
          .rate(
            _stars,
            _comment.text.trim().isEmpty ? null : _comment.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for rating GoDoctor!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  static const _words = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
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
            'How is GoDoctor working for you?',
            textAlign: TextAlign.center,
            style: theme.titleMedium,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 38,
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    LucideIcons.star,
                    color: i <= _stars
                        ? AppColors.warning
                        : AppColors.borderStrong,
                  ),
                ),
            ],
          ),
          Text(
            _words[_stars],
            textAlign: TextAlign.center,
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _comment,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Tell us more (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _stars == 0 || _saving ? null : _save,
            child: Text(_saving ? 'Sending…' : 'Submit rating'),
          ),
        ],
      ),
    );
  }
}
