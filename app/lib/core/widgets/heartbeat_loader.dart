import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A beating heart ("lub-dub") over a moving ECG trace. Used while a screen
/// loads, between screens, and between tabs. Galleries and lists keep their
/// own skeleton placeholders instead.
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
    duration: const Duration(milliseconds: 1100),
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
// Screen changes
// ---------------------------------------------------------------------------

/// Full-screen cover shown while the next screen appears.
class _HeartbeatCover extends StatelessWidget {
  const _HeartbeatCover();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: const Center(child: HeartbeatLoader()),
    );
  }
}

/// Page transition used app-wide (set in the theme): a short heartbeat, then
/// the new screen fades up. Going back is a quick fade with no heartbeat.
class HeartbeatPageTransitionsBuilder extends PageTransitionsBuilder {
  const HeartbeatPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 750);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => HeartbeatTransition(animation: animation, child: child);
}

/// The heartbeat-then-reveal animation for one incoming screen.
class HeartbeatTransition extends StatelessWidget {
  const HeartbeatTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  static final _cover = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 17),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 25),
  ]);

  static const _reveal = Interval(0.55, 1.0, curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        // Leaving (back): quick fade, no heartbeat. The widget structure is
        // the same in every state so the page is never rebuilt from scratch.
        final leaving = animation.status == AnimationStatus.reverse;
        final cover = leaving ? 0.0 : _cover.transform(t);
        final reveal = leaving
            ? Curves.easeIn.transform(t)
            : _reveal.transform(t);
        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: reveal,
              child: Transform.translate(
                offset: Offset(0, leaving ? 0 : 14 * (1 - reveal)),
                child: child,
              ),
            ),
            if (cover > 0)
              IgnorePointer(
                child: Opacity(opacity: cover, child: const _HeartbeatCover()),
              ),
          ],
        );
      },
    );
  }
}

/// Plays the heartbeat when switching bottom-nav tabs, except on tabs in
/// [quietTabs] (galleries and lists, which show their own skeletons).
class HeartbeatTabSwitcher extends StatefulWidget {
  const HeartbeatTabSwitcher({
    super.key,
    required this.index,
    required this.child,
    this.quietTabs = const {},
  });

  final int index;
  final Widget child;
  final Set<int> quietTabs;

  @override
  State<HeartbeatTabSwitcher> createState() => _HeartbeatTabSwitcherState();
}

class _HeartbeatTabSwitcherState extends State<HeartbeatTabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    value: 1,
  );

  static final _cover = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 62),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 38),
  ]);

  @override
  void didUpdateWidget(HeartbeatTabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && !widget.quietTabs.contains(widget.index)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final cover = _c.isAnimating ? _cover.transform(_c.value) : 0.0;
            if (cover <= 0) return const SizedBox.shrink();
            return IgnorePointer(
              child: Opacity(opacity: cover, child: const _HeartbeatCover()),
            );
          },
        ),
      ],
    );
  }
}
