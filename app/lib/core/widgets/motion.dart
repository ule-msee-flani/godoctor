import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

/// GoDoctor's small motion kit: calm, short animations that say "something
/// is waiting for you" or "done", never decoration for its own sake. Every
/// looping or entrance animation stays still when the phone's "remove
/// animations" accessibility setting is on.
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// The notification bell: rings now and then while something is unread,
/// with a count badge that pops when it changes.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.count,
    required this.onPressed,
    this.tooltip = 'Notifications',
  });

  final int count;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return PopBadge(
      count: count,
      offset: const Offset(-6, 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Ringing(active: count > 0, child: const Icon(LucideIcons.bell)),
      ),
    );
  }
}

/// Swings its child like a ringing bell: once when [active] turns on, then
/// every [every] while it stays on.
class Ringing extends StatefulWidget {
  const Ringing({
    super.key,
    required this.active,
    required this.child,
    this.every = const Duration(seconds: 6),
  });

  final bool active;
  final Widget child;
  final Duration every;

  @override
  State<Ringing> createState() => _RingingState();
}

class _RingingState extends State<Ringing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(Ringing old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _start();
    if (!widget.active && old.active) _stop();
  }

  void _start() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || reduceMotion(context)) return;
      _c.forward(from: 0);
      _timer?.cancel();
      _timer = Timer.periodic(widget.every, (_) {
        if (mounted) _c.forward(from: 0);
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    _c.stop();
    _c.value = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        // Four quick swings that die away, pivoting at the top of the bell.
        final angle = math.sin(t * math.pi * 8) * 0.38 * (1 - t);
        return Transform.rotate(
          angle: angle,
          alignment: const Alignment(0, -0.9),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Floats its child gently up and down while [active] (e.g. the Chats tab
/// icon while there are unread messages).
class Bobbing extends StatefulWidget {
  const Bobbing({
    super.key,
    required this.active,
    required this.child,
    this.height = 3,
  });

  final bool active;
  final Widget child;
  final double height;

  @override
  State<Bobbing> createState() => _BobbingState();
}

class _BobbingState extends State<Bobbing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Bobbing old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.active && !reduceMotion(context);
    if (on && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!on && _c.isAnimating) {
      _c.animateTo(0, duration: const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          -widget.height * Curves.easeInOut.transform(_c.value),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// A count badge that pops in, and bounces when the number changes.
class PopBadge extends StatelessWidget {
  const PopBadge({
    super.key,
    required this.count,
    required this.child,
    this.offset,
  });

  final int count;
  final Widget child;
  final Offset? offset;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      offset: offset,
      label: TweenAnimationBuilder<double>(
        key: ValueKey(count),
        tween: Tween(begin: reduceMotion(context) ? 1 : 0.4, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.elasticOut,
        builder: (context, s, child) => Transform.scale(scale: s, child: child),
        child: Text(count > 9 ? '9+' : '$count'),
      ),
      child: child,
    );
  }
}

/// The handshake beside a greeting: a friendly little shake when the
/// screen opens, then still.
class HandshakeWave extends StatefulWidget {
  const HandshakeWave({super.key, this.size = 26});

  final double size;

  @override
  State<HandshakeWave> createState() => _HandshakeWaveState();
}

class _HandshakeWaveState extends State<HandshakeWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!reduceMotion(context) && _c.status == AnimationStatus.dismissed) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hello',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Three quick shakes that die away.
          final t = _c.value;
          final swing = math.sin(t * 3 * 2 * math.pi) * (1 - t);
          return Transform.translate(
            offset: Offset(0, -3 * swing.abs()),
            child: Transform.rotate(angle: 0.14 * swing, child: child),
          );
        },
        child: Icon(
          LucideIcons.handshake,
          size: widget.size,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Pops its child in (a chosen tab's icon).
class TabPop extends StatelessWidget {
  const TabPop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.72, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: child,
    );
  }
}

/// Shrinks a touch when pressed, like a real button (cards and tiles).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduceMotion(context) ? widget.scale : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides its child up into place the first time it appears;
/// give list items increasing [index]es for a gentle cascade.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status != AnimationStatus.dismissed || _delay != null) return;
    if (reduceMotion(context)) {
      _c.value = 1;
      return;
    }
    final wait = Duration(milliseconds: 55 * math.min(widget.index, 8));
    _delay = Timer(wait, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A number that counts up to its value (stats, totals).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final num value;
  final String Function(num v) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text(format(value is int ? v.round() : v), style: style),
    );
  }
}

/// A check mark that draws itself inside a soft circle ("Paid", "Taken").
class AnimatedCheck extends StatelessWidget {
  const AnimatedCheck({
    super.key,
    this.size = 84,
    this.color = AppColors.success,
    this.background = AppColors.successSoft,
    this.haptic = true,
  });

  final double size;
  final Color color;
  final Color background;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 750),
      onEnd: haptic ? HapticFeedback.lightImpact : null,
      builder: (context, t, _) {
        final circle = Curves.easeOutBack.transform((t * 1.6).clamp(0, 1));
        final stroke = Curves.easeOut.transform(
          ((t - 0.35) / 0.65).clamp(0, 1),
        );
        return Transform.scale(
          scale: 0.6 + 0.4 * circle,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: CustomPaint(
              painter: _CheckPainter(progress: stroke, color: color),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.72, w * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// A status dot that breathes (online, live).
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s * 2.2,
      height: s * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s + s * 1.2 * _c.value,
              height: s + s * 1.2 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s,
              height: s,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live bars that follow the voice while recording (0..1 levels).
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.levels,
    this.color = AppColors.danger,
    this.height = 26,
  });

  final List<double> levels;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final l in levels)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              width: 3,
              height: math.max(3, height * l.clamp(0, 1)),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
