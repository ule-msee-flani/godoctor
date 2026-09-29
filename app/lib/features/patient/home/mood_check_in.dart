import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';

enum Mood { great, good, okay, low, unwell }

extension MoodLook on Mood {
  String get emoji => switch (this) {
    Mood.great => '😄',
    Mood.good => '🙂',
    Mood.okay => '😐',
    Mood.low => '😔',
    Mood.unwell => '🤒',
  };

  String get label => switch (this) {
    Mood.great => 'Great',
    Mood.good => 'Good',
    Mood.okay => 'Okay',
    Mood.low => 'Low',
    Mood.unwell => 'Unwell',
  };
}

String _todayKey() {
  final n = DateTime.now();
  return 'mood_${n.year}-${n.month}-${n.day}';
}

/// Today's mood, remembered on this phone for the day.
final todaysMoodProvider = FutureProvider.autoDispose<Mood?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_todayKey());
    return Mood.values.where((m) => m.name == v).firstOrNull;
  } catch (_) {
    return null;
  }
});

/// "How are you feeling today?" — five faces. Great or good gets a cheer,
/// low gets a gentle way to talk to someone, unwell gets the common
/// problems to start a consultation.
class MoodCheckIn extends ConsumerStatefulWidget {
  const MoodCheckIn({super.key, required this.onUnwell});

  /// Start a consultation about [symptom] in [specialty].
  final void Function(String specialty, String symptom) onUnwell;

  @override
  ConsumerState<MoodCheckIn> createState() => _MoodCheckInState();
}

class _MoodCheckInState extends ConsumerState<MoodCheckIn> {
  Mood? _picked;

  /// "Change" asks again, even when a mood was saved earlier today.
  bool _asking = false;

  static const _unwellOptions = [
    ('Headache', 'General Practice'),
    ('Fever', 'General Practice'),
    ('Cough or cold', 'General Practice'),
    ('Stomach upset', 'General Practice'),
    ('Skin problem', 'Dermatology'),
    ('My child is unwell', 'Pediatrics'),
  ];

  Future<void> _pick(Mood m) async {
    HapticFeedback.selectionClick();
    setState(() {
      _picked = m;
      _asking = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_todayKey(), m.name);
    } catch (_) {}
    try {
      await ref.read(profileRepositoryProvider).logMood(m.name);
    } catch (_) {
      // A check-in that doesn't reach the server isn't worth an error.
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(todaysMoodProvider).valueOrNull;
    final mood = _asking ? null : _picked ?? saved;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: mood == null
          ? _Ask(key: const ValueKey('ask'), onPick: _pick)
          : _Answer(
              key: ValueKey(mood),
              mood: mood,
              unwellOptions: _unwellOptions,
              onUnwell: widget.onUnwell,
              onChange: () => setState(() {
                _picked = null;
                _asking = true;
              }),
            ),
    );
  }
}

class _Ask extends StatelessWidget {
  const _Ask({super.key, required this.onPick});

  final ValueChanged<Mood> onPick;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: AppColors.skyGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling today?',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final m in Mood.values)
                Semantics(
                  button: true,
                  label: m.label,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onPick(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              m.emoji,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(m.label, style: text.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    super.key,
    required this.mood,
    required this.unwellOptions,
    required this.onUnwell,
    required this.onChange,
  });

  final Mood mood;
  final List<(String, String)> unwellOptions;
  final void Function(String specialty, String symptom) onUnwell;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (gradient, title, line) = switch (mood) {
      Mood.great || Mood.good => (
        AppColors.mintGradient,
        'Love that!',
        'Keep it up. A quick look at your Well guide keeps you ahead.',
      ),
      Mood.okay => (
        AppColors.peachGradient,
        'Thanks for checking in.',
        'Small things help: water, a short walk and a good night\'s sleep.',
      ),
      Mood.low => (
        AppColors.lavenderGradient,
        'We\'re here for you.',
        'Talking helps. Our mental health doctors are a tap away.',
      ),
      Mood.unwell => (
        AppColors.peachGradient,
        'Sorry you\'re unwell.',
        'What\'s bothering you? A doctor can help today.',
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mood.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line,
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onChange, child: const Text('Change')),
            ],
          ),
          const SizedBox(height: 8),
          switch (mood) {
            Mood.great || Mood.good => FilledButton.tonal(
              onPressed: () => context.push('/patient/well-guide'),
              child: const Text('Open my Well guide'),
            ),
            Mood.okay => const SizedBox.shrink(),
            Mood.low => FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lavender,
              ),
              onPressed: () => context.push('/patient/specialty/mental-health'),
              child: const Text('Talk to someone'),
            ),
            Mood.unwell => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, specialty) in unwellOptions)
                  ActionChip(
                    backgroundColor: AppColors.white,
                    label: Text(label),
                    onPressed: () => onUnwell(specialty, label),
                  ),
              ],
            ),
          },
        ],
      ),
    );
  }
}
