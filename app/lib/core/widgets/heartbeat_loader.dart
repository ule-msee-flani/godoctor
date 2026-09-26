import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A beating heart ("lub-dub") over a moving ECG trace: GoDoctor's sign for
/// "one moment". Shown when something really takes time (see
/// [DelayedHeartbeat]) and at big moments (paying, the doctor joining).
/// Galleries and lists use skeleton placeholders instead.
class HeartbeatLoader extends StatefulWidget {
  const HeartbeatLoader({super.key, this.size = 56, this.message});

  /// Height of the heart; the trace is drawn beneath at ~2.4x this width.
  final double size;
  final String? message;

  @override
  State<HeartbeatLoader> createState() => _HeartbeatLoaderState();
}

class _HeartbeatLoaderState extends State<HeartbeatLoader>
    with SingleTickerProviderStateMixin {
  // One heartbeat cycle (~70 bpm, a calm resting pulse).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Lub (bigger) then dub (smaller), then rest.
  static double _beat(double t) {
    double pulse(double center, double width, double height) {
      final d = (t - center).abs() / width;
      return d >= 1 ? 0 : height * (1 - d * d);
    }

    return pulse(0.10, 0.09, 0.20) + pulse(0.30, 0.08, 0.12);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      label: widget.message ?? 'Loading',
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1 + _beat(_c.value),
                  child: CustomPaint(
                    size: Size(s, s * 0.9),
                    painter: _HeartPainter(AppColors.danger),
                  ),
                ),
                SizedBox(height: s * 0.18),
                CustomPaint(
                  size: Size(s * 2.4, s * 0.5),
                  painter: _TracePainter(
                    progress: _c.value,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          if (widget.message != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  const _HeartPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.10, h * 0.66, -w * 0.05, h * 0.28, w * 0.24, h * 0.08)
      ..cubicTo(w * 0.38, -h * 0.02, w * 0.48, h * 0.08, w / 2, h * 0.22)
      ..cubicTo(w * 0.52, h * 0.08, w * 0.62, -h * 0.02, w * 0.76, h * 0.08)
      ..cubicTo(w * 1.05, h * 0.28, w * 0.90, h * 0.66, w / 2, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HeartPainter old) => old.color != color;
}

/// An ECG line (flat, P-wave, QRS spike, T-wave) revealed left to right in
/// step with the beat, with a fading tail.
class _TracePainter extends CustomPainter {
  const _TracePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _points = <Offset>[
    Offset(0.00, 0.60),
    Offset(0.18, 0.60),
    Offset(0.24, 0.50), // P
    Offset(0.30, 0.60),
    Offset(0.38, 0.60),
    Offset(0.42, 0.70), // Q
    Offset(0.47, 0.02), // R
    Offset(0.52, 0.95), // S
    Offset(0.56, 0.60),
    Offset(0.66, 0.60),
    Offset(0.74, 0.42), // T
    Offset(0.82, 0.60),
    Offset(1.00, 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _points.length; i++) {
      final p = Offset(_points[i].dx * size.width, _points[i].dy * size.height);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    final head = progress * size.width;
    final tail = math.max(0.0, head - size.width * 0.55);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(tail, 0, head + 1, size.height));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: 0), color],
        ).createShader(Rect.fromLTRB(tail, 0, head + 1, size.height)),
    );
    canvas.restore();
    // Faint baseline so the trace has something to ride on.
    canvas.drawLine(
      Offset(0, size.height * 0.60),
      Offset(size.width, size.height * 0.60),
      Paint()
        ..color = AppColors.border
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Screen changes and waits
// ---------------------------------------------------------------------------

/// App-wide page transition (set in the theme): the new screen fades up
/// quickly, so fast screens feel fast. The heartbeat is kept for real waits
/// and big moments.
class CalmPageTransitionsBuilder extends PageTransitionsBuilder {
  const CalmPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 280);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// The heartbeat, but only if the wait lasts longer than [delay]: quick
/// loads never flash it, slow ones get the calm "one moment" sign.
class DelayedHeartbeat extends StatefulWidget {
  const DelayedHeartbeat({
    super.key,
    this.size = 48,
    this.message,
    this.delay = const Duration(milliseconds: 250),
  });

  final double size;
  final String? message;
  final Duration delay;

  @override
  State<DelayedHeartbeat> createState() => _DelayedHeartbeatState();
}

class _DelayedHeartbeatState extends State<DelayedHeartbeat> {
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _show ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: _show
        ? HeartbeatLoader(size: widget.size, message: widget.message)
        : SizedBox(height: widget.size * 1.6),
  );
}
