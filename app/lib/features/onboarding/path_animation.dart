import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/motion.dart';

/// Between two questions: a winding path with a glowing dot walking from
/// one stop to the next, and a short word of encouragement. Calls [onDone]
/// when the walk ends.
class PathTravel extends StatefulWidget {
  const PathTravel({
    super.key,
    required this.stops,
    required this.from,
    required this.to,
    required this.message,
    required this.onDone,
  });

  /// How many stops the path has (one per question).
  final int stops;
  final int from;
  final int to;
  final String message;
  final VoidCallback onDone;

  @override
  State<PathTravel> createState() => _PathTravelState();
}

class _PathTravelState extends State<PathTravel>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(
          vsync: this,
          duration: reduceMotion(context)
              ? const Duration(milliseconds: 250)
              : const Duration(milliseconds: 1100),
        )
        ..forward().whenComplete(() {
          if (mounted) widget.onDone();
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walk = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.1, 0.85, curve: Curves.easeInOutCubic),
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final p = widget.stops <= 1
            ? 1.0
            : (widget.from + (widget.to - widget.from) * walk.value) /
                  (widget.stops - 1);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 260,
              width: double.infinity,
              child: CustomPaint(
                painter: _PathPainter(
                  stops: widget.stops,
                  progress: p.clamp(0.0, 1.0),
                  glow: 0.6 + 0.4 * math.sin(_c.value * math.pi * 4).abs(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Opacity(
              opacity: Curves.easeOut.transform(
                (_c.value * 2.2).clamp(0.0, 1.0),
              ),
              child: Text(
                widget.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.stops,
    required this.progress,
    required this.glow,
  });

  final int stops;
  final double progress;
  final double glow;

  /// A gentle S-shaped trail from bottom-left to top-right.
  Path _trail(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.08, h * 0.86)
      ..cubicTo(w * 0.42, h * 0.98, w * 0.18, h * 0.46, w * 0.5, h * 0.5)
      ..cubicTo(w * 0.82, h * 0.54, w * 0.58, h * 0.04, w * 0.92, h * 0.14);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trail = _trail(size);
    final metric = trail.computeMetrics().first;
    final len = metric.length;

    // The whole way, dotted.
    final dots = Paint()..color = AppColors.border;
    for (var d = 0.0; d < len; d += 14) {
      final t = metric.getTangentForOffset(d)!;
      canvas.drawCircle(t.position, 2.6, dots);
    }

    // The way walked so far.
    final walked = metric.extractPath(0, len * progress);
    canvas.drawPath(
      walked,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // Stops along the way; the last one is the finish.
    for (var i = 0; i < stops; i++) {
      final f = stops == 1 ? 1.0 : i / (stops - 1);
      final pos = metric.getTangentForOffset(len * f)!.position;
      final reached = f <= progress + 0.001;
      final last = i == stops - 1;
      final r = last ? 11.0 : 7.0;
      canvas.drawCircle(
        pos,
        r,
        Paint()..color = reached ? AppColors.primary : AppColors.white,
      );
      canvas.drawCircle(
        pos,
        r,
        Paint()
          ..color = reached ? AppColors.primary : AppColors.borderStrong
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      if (last) {
        canvas.drawCircle(
          pos,
          4,
          Paint()..color = reached ? AppColors.white : AppColors.borderStrong,
        );
      }
    }

    // The walker.
    final head = metric.getTangentForOffset(len * progress)!.position;
    canvas.drawCircle(
      head,
      18 * glow,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.18)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
    );
    canvas.drawCircle(head, 10, Paint()..color = AppColors.white);
    canvas.drawCircle(head, 7, Paint()..color = AppColors.accentTeal);
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.progress != progress || old.glow != glow || old.stops != stops;
}

/// The end of the path: confetti, a check, and a send-off line.
class PathFinish extends StatefulWidget {
  const PathFinish({
    super.key,
    required this.headline,
    required this.line,
    required this.button,
    required this.onGo,
    this.note,
  });

  final String headline;
  final String line;
  final String? note;
  final String button;
  final VoidCallback onGo;

  @override
  State<PathFinish> createState() => _PathFinishState();
}

class _PathFinishState extends State<PathFinish>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();
  final _pieces = List.generate(46, (i) => _Piece(math.Random(i * 7 + 3)));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Stack(
      children: [
        if (!reduceMotion(context))
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) =>
                    CustomPaint(painter: _ConfettiPainter(_pieces, _c.value)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              const AnimatedCheck(size: 96),
              const SizedBox(height: 28),
              FadeSlideIn(
                index: 1,
                child: Text(
                  widget.headline,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FadeSlideIn(
                index: 2,
                child: Text(
                  widget.line,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: AppColors.inkSoft),
                ),
              ),
              if (widget.note != null) ...[
                const SizedBox(height: 18),
                FadeSlideIn(
                  index: 3,
                  child: Text(
                    widget.note!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              FadeSlideIn(
                index: 4,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    onPressed: widget.onGo,
                    child: Text(widget.button),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Piece {
  _Piece(math.Random r)
    : x = r.nextDouble(),
      delay = r.nextDouble() * 0.35,
      speed = 0.7 + r.nextDouble() * 0.6,
      drift = (r.nextDouble() - 0.5) * 0.25,
      spin = (r.nextDouble() - 0.5) * 12,
      size = 6 + r.nextDouble() * 6,
      color = const [
        AppColors.primary,
        AppColors.accentTeal,
        AppColors.warning,
        AppColors.success,
        AppColors.danger,
      ][r.nextInt(5)];

  final double x, delay, speed, drift, spin, size;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final life = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (life <= 0) continue;
      final y = -20 + (size.height * 0.75) * life * p.speed;
      final x = size.width * (p.x + p.drift * life);
      final paint = Paint()
        ..color = p.color.withValues(alpha: (1 - life).clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * life);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
