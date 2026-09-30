import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/repository_providers.dart';
import '../../selfcare/stick_scene.dart';

/// In the order they're offered.
enum Mood {
  happy,
  sad,
  anxious,
  angry,
  underTheWeather,
  tired,
  moody,
  calm,
  okay,
}

extension MoodLook on Mood {
  String get label => switch (this) {
    Mood.happy => 'Happy',
    Mood.calm => 'Calm',
    Mood.okay => 'Okay',
    Mood.tired => 'Tired',
    Mood.moody => 'Moody',
    Mood.sad => 'Sad',
    Mood.anxious => 'Anxious',
    Mood.angry => 'Angry',
    Mood.underTheWeather => 'Under the weather',
  };

  /// As saved on the server.
  String get key => switch (this) {
    Mood.underTheWeather => 'under_the_weather',
    _ => name,
  };

  Color get color => switch (this) {
    Mood.happy => const Color(0xFFF7C23E),
    Mood.calm => const Color(0xFF5BB8F0),
    Mood.okay => const Color(0xFF3CC39A),
    Mood.tired => const Color(0xFF6C6FD8),
    Mood.moody => const Color(0xFFF29A38),
    Mood.sad => const Color(0xFF8E5BD6),
    Mood.anxious => const Color(0xFF34B27D),
    Mood.angry => const Color(0xFFF2545B),
    Mood.underTheWeather => const Color(0xFF7C9CB8),
  };
}

/// A saved mood, including the first set of names ("great", "low"...).
Mood? moodFromKey(String? key) => switch (key) {
  'great' || 'good' => Mood.happy,
  'low' => Mood.sad,
  'unwell' => Mood.underTheWeather,
  _ => Mood.values.where((m) => m.key == key).firstOrNull,
};

String _todayKey() {
  final n = DateTime.now();
  return 'mood_${n.year}-${n.month}-${n.day}';
}

/// Today's mood, remembered on this phone for the day.
final todaysMoodProvider = FutureProvider.autoDispose<Mood?>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return moodFromKey(prefs.getString(_todayKey()));
  } catch (_) {
    return null;
  }
});

/// "How do you feel today?" — a row of feelings, each a little shape. What
/// comes next fits the feeling: a cheer, a practice to try, someone to talk
/// to, or (under the weather) the common problems to start a consultation.
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
      await prefs.setString(_todayKey(), m.key);
    } catch (_) {}
    try {
      await ref.read(profileRepositoryProvider).logMood(m.key);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'How do you feel today?',
          style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: Mood.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final m = Mood.values[i];
              return _MoodCard(mood: m, onTap: () => onPick(m));
            },
          ),
        ),
      ],
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.mood, required this.onTap});

  final Mood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wide = mood == Mood.underTheWeather;
    return Semantics(
      container: true,
      button: true,
      label: mood.label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            width: wide ? 112 : 88,
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Text(
                  mood.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.ink),
                ),
                const Spacer(),
                MoodGlyph(mood: mood, size: 42),
              ],
            ),
          ),
        ),
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
      Mood.happy => (
        AppColors.mintGradient,
        'Love that!',
        'Keep it going. Share the good mood with someone today.',
      ),
      Mood.calm => (
        AppColors.skyGradient,
        'Nice and steady.',
        'Protect that calm: a short walk or a chat with a friend.',
      ),
      Mood.okay => (
        AppColors.peachGradient,
        'Thanks for checking in.',
        'Small things help: water, a short walk and a good night\'s sleep.',
      ),
      Mood.tired => (
        AppColors.lavenderGradient,
        'Rest matters.',
        'Your body may be asking for sleep. This can help tonight.',
      ),
      Mood.moody => (
        AppColors.peachGradient,
        'Up-and-down days happen.',
        'Naming the feeling helps it settle. Try this for two minutes.',
      ),
      Mood.sad => (
        AppColors.lavenderGradient,
        'We\'re here for you.',
        'Talking helps. Our mental health doctors are a tap away.',
      ),
      Mood.anxious => (
        AppColors.skyGradient,
        'Let\'s slow things down.',
        'Breathe in for 4 and out for 6. Two minutes can help.',
      ),
      Mood.angry => (
        AppColors.peachGradient,
        'That\'s a lot to hold.',
        'A short pause takes the heat out before you act.',
      ),
      Mood.underTheWeather => (
        AppColors.peachGradient,
        'Sorry you\'re under the weather.',
        'What\'s bothering you? A doctor can help today.',
      ),
    };

    Widget practice(String label, String item, {bool strong = true}) {
      void onPressed() => context.push('/patient/practice/$item');
      const icon = Icon(LucideIcons.play, size: 16);
      return strong
          ? FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            )
          : OutlinedButton.icon(
              style: OutlinedButton.styleFrom(backgroundColor: AppColors.white),
              onPressed: onPressed,
              icon: icon,
              label: Text(label),
            );
    }

    final talk = FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.lavender),
      onPressed: () => context.push('/patient/specialty/mental-health'),
      child: const Text('Talk to someone'),
    );

    final actions = <Widget>[
      ...switch (mood) {
        Mood.happy => [practice('Reach out', 'reach-out')],
        Mood.calm => [practice('Take a walk', 'walk-10')],
        Mood.okay => [practice('Three good things', 'three-good')],
        Mood.tired => [practice('Wind down tonight', 'wind-down')],
        Mood.moody => [practice('Name it to tame it', 'name-it')],
        Mood.sad => [
          talk,
          practice('Lift your mood', 'three-good', strong: false),
        ],
        Mood.anxious => [practice('Breathe with me', 'calm-breathing'), talk],
        Mood.angry => [practice('Pause and cool down', 'cool-down')],
        Mood.underTheWeather => const <Widget>[],
      },
    ];

    final scene = mood == Mood.sad ? StickSceneKind.sadRain : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sad: a little scene says it first; the words come under it.
          if (scene != null)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 12),
              child: AspectRatio(
                aspectRatio: 2,
                child: StickScene(scene: scene),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (scene == null) ...[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: MoodGlyph(mood: mood, size: 34),
                ),
                const SizedBox(width: 12),
              ],
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
          const SizedBox(height: 10),
          if (mood == Mood.underTheWeather)
            Wrap(
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
            )
          else
            Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// The little shape for a feeling: a sunny flower for happy, a pebble for
/// calm, a moon for tired, waves for anxious, a spiky star for angry...
class MoodGlyph extends StatelessWidget {
  const MoodGlyph({super.key, required this.mood, this.size = 40});

  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _GlyphPainter(mood)),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.mood);

  final Mood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final fill = Paint()
      ..color = mood.color
      ..isAntiAlias = true;
    switch (mood) {
      case Mood.happy:
        // A flower: eight round petals and a round middle.
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawCircle(
            c + Offset(math.cos(a), math.sin(a)) * (s * 0.27),
            s * 0.17,
            fill,
          );
        }
        canvas.drawCircle(c, s * 0.2, fill);
      case Mood.calm:
        // A smooth pebble, gently tilted.
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..rotate(-0.3);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset.zero,
            width: s * 0.86,
            height: s * 0.6,
          ),
          fill,
        );
        canvas.restore();
      case Mood.okay:
        // A steady capsule.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s * 0.86, height: s * 0.4),
            Radius.circular(s * 0.2),
          ),
          fill,
        );
      case Mood.tired:
        // A crescent moon.
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: s * 0.4)),
          Path()..addOval(
            Rect.fromCircle(
              center: c + Offset(s * 0.2, -s * 0.12),
              radius: s * 0.33,
            ),
          ),
        );
        canvas.drawPath(moon, fill);
      case Mood.moody:
        // Two moods in one circle.
        final r = Rect.fromCircle(center: c, radius: s * 0.4);
        canvas.drawArc(r, math.pi * 0.75, math.pi, true, fill);
        canvas.drawArc(
          r,
          -math.pi * 0.25,
          math.pi,
          true,
          Paint()..color = Mood.sad.color,
        );
      case Mood.sad:
        // A drooping bean.
        final p = Path()
          ..moveTo(s * 0.2, s * 0.62)
          ..cubicTo(s * 0.02, s * 0.36, s * 0.3, s * 0.1, s * 0.52, s * 0.2)
          ..cubicTo(s * 0.66, s * 0.26, s * 0.62, s * 0.4, s * 0.76, s * 0.46)
          ..cubicTo(s * 0.98, s * 0.56, s * 0.86, s * 0.9, s * 0.58, s * 0.86)
          ..cubicTo(s * 0.42, s * 0.84, s * 0.34, s * 0.8, s * 0.2, s * 0.62)
          ..close();
        canvas.drawPath(p, fill);
      case Mood.anxious:
        // Restless waves.
        final line = Paint()
          ..color = mood.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.09
          ..strokeCap = StrokeCap.round;
        for (var row = 0; row < 3; row++) {
          final y = s * (0.3 + row * 0.2);
          final wave = Path()..moveTo(s * 0.1, y);
          for (var k = 0; k < 4; k++) {
            final x0 = s * (0.1 + k * 0.2);
            wave.quadraticBezierTo(
              x0 + s * 0.1,
              y + (k.isEven ? -s * 0.08 : s * 0.08),
              x0 + s * 0.2,
              y,
            );
          }
          canvas.drawPath(wave, line);
        }
      case Mood.angry:
        // A spiky star.
        final star = Path();
        const points = 12;
        for (var i = 0; i < points * 2; i++) {
          final r = i.isEven ? s * 0.47 : s * 0.27;
          final a = i * math.pi / points - math.pi / 2;
          final p = c + Offset(math.cos(a), math.sin(a)) * r;
          i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), fill);
      case Mood.underTheWeather:
        // A little rain cloud.
        final cloud = Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(s * 0.34, s * 0.44),
              radius: s * 0.17,
            ),
          )
          ..addOval(
            Rect.fromCircle(
              center: Offset(s * 0.56, s * 0.36),
              radius: s * 0.22,
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(s * 0.14, s * 0.42, s * 0.88, s * 0.62),
              Radius.circular(s * 0.1),
            ),
          );
        canvas.drawPath(cloud, fill);
        final drop = Paint()
          ..color = const Color(0xFF4E9BE0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.07
          ..strokeCap = StrokeCap.round;
        for (final x in [0.34, 0.54, 0.74]) {
          canvas.drawLine(
            Offset(s * x, s * 0.72),
            Offset(s * (x - 0.05), s * 0.86),
            drop,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.mood != mood;
}
