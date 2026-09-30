import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Moments in a little story, acted out by a stick girl: from sitting in the
/// rain to jumping in the sun.
enum StickSceneKind {
  /// Hunched on a bench, hugging herself, rain pouring.
  sadRain,

  /// Looking up, thinking; the rain easing.
  thinkBack,

  /// Counting three good things as they pop up; the cloud drifting off.
  threeThings,

  /// Hand on chin, wondering why each went well.
  askWhy,

  /// Standing and waving at sunset, a week of evenings filling in.
  everyEvening,

  /// Jumping for joy.
  celebrate,
}

extension StickSceneWords on StickSceneKind {
  /// For screen readers.
  String get description => switch (this) {
    StickSceneKind.sadRain => 'A girl sits hunched on a bench in the rain.',
    StickSceneKind.thinkBack => 'The rain eases. The girl looks up, thinking.',
    StickSceneKind.threeThings =>
      'The girl counts three good things as the cloud drifts away.',
    StickSceneKind.askWhy => 'The girl rests her chin on her hand, wondering.',
    StickSceneKind.everyEvening =>
      'The girl stands and waves at sunset as a week fills in.',
    StickSceneKind.celebrate => 'The girl jumps for joy in the sun.',
  };
}

/// An animated stick-figure scene, drawn live (no video, no image files).
/// Changing [scene] doesn't cut: she moves from one pose to the next and the
/// weather changes around her.
class StickScene extends StatefulWidget {
  const StickScene({super.key, required this.scene, this.from});

  final StickSceneKind scene;

  /// Where she starts when this first appears (then moves to [scene]).
  final StickSceneKind? from;

  @override
  State<StickScene> createState() => _StickSceneState();
}

class _StickSceneState extends State<StickScene> with TickerProviderStateMixin {
  /// Everything loops every four seconds.
  static const _loopSeconds = 4.0;

  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final AnimationController _blend = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  late StickSceneKind _prev = widget.from ?? widget.scene;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    if (widget.from != null && widget.from != widget.scene) {
      _blend.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Remove animations" in the phone's settings: hold one calm frame.
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _loop
        ..stop()
        ..value = 0.45;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(StickScene old) {
    super.didUpdateWidget(old);
    if (old.scene != widget.scene) {
      _prev = old.scene;
      _still ? _blend.value = 1 : _blend.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _blend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: widget.scene.description,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_loop, _blend]),
          builder: (context, _) {
            final sec = _loop.value * _loopSeconds;
            final t = Curves.easeInOutCubic.transform(_blend.value);
            return CustomPaint(
              size: Size.infinite,
              painter: _ScenePainter(
                _Stage.lerp(
                  _Stage.at(_prev, sec),
                  _Stage.at(widget.scene, sec),
                  t,
                ),
                sec,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Everything that can change: her joints and face, and the world around.
/// Angles are from straight down, positive towards the right.
class _Stage {
  const _Stage({
    required this.hipX,
    required this.hipY,
    required this.lean,
    required this.headTilt,
    required this.armNU,
    required this.armNF,
    required this.armFU,
    required this.armFF,
    required this.legNU,
    required this.legNF,
    required this.legFU,
    required this.legFF,
    required this.smile,
    required this.faceShift,
    required this.bg,
    this.ponyLift = 0,
    this.ponySway = 0,
    this.rain = 0,
    this.cloud = 0,
    this.cloudDx = 0,
    this.gloom = 0,
    this.sun = 0,
    this.sunLow = 0,
    this.bench = 1,
    this.bubble = 0,
    this.trail = 0,
    this.items = const [0, 0, 0],
    this.question = 0,
    this.questionAt = 0,
    this.week = 0,
    this.weekFilled = 0,
    this.sparkles = 0,
  });

  final double hipX, hipY, lean, headTilt;

  /// Near (front) and far arm: upper arm, forearm.
  final double armNU, armNF, armFU, armFF;

  /// Near and far leg: thigh, shin.
  final double legNU, legNF, legFU, legFF;

  /// -1 frown .. 1 smile; 1 facing right .. 0 facing us.
  final double smile, faceShift;
  final double ponyLift, ponySway;
  final double rain, cloud, cloudDx, gloom, sun, sunLow, bench;
  final double bubble, trail;
  final List<double> items;
  final double question, questionAt;
  final double week, weekFilled;
  final double sparkles;
  final Color bg;

  static double _wave(double sec, double period) =>
      math.sin(2 * math.pi * sec / period);

  static double _pop(double sec, double at) {
    final x = ((sec - at) / 0.4).clamp(0.0, 1.0);
    final out = 1 - ((sec - 3.6) / 0.35).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(x) * out;
  }

  /// The scene [kind], [sec] seconds into the four-second loop.
  static _Stage at(StickSceneKind kind, double sec) {
    final breath = _wave(sec, 4);
    switch (kind) {
      case StickSceneKind.sadRain:
        // Little sobs, in bursts.
        final burst = math.max(0.0, _wave(sec, 4));
        final sob = _wave(sec, 0.5) * burst * burst;
        return _Stage(
          hipX: 112,
          hipY: 117,
          lean: 0.42 + 0.02 * breath,
          headTilt: 0.55 + 0.04 * sob,
          armNU: 0.5,
          armNF: -1.9 + 0.04 * sob,
          armFU: 0.75,
          armFF: -1.6,
          legNU: 1.45,
          legNF: -0.22,
          legFU: 1.36,
          legFF: -0.3,
          smile: -1,
          faceShift: 1,
          ponySway: 0.4 * breath,
          rain: 1,
          cloud: 1,
          gloom: 1,
          bg: const Color(0xFFE2E5F1),
        );
      case StickSceneKind.thinkBack:
        return _Stage(
          hipX: 112,
          hipY: 117,
          lean: 0.2 + 0.015 * breath,
          headTilt: -0.22 + 0.06 * breath,
          armNU: 0.35,
          armNF: 1.15,
          armFU: 0.25,
          armFF: 1.05,
          legNU: 1.45,
          legNF: 0,
          legFU: 1.36,
          legFF: -0.08,
          smile: -0.15,
          faceShift: 1,
          ponySway: 0.6 * breath,
          rain: 0.22,
          cloud: 0.85,
          cloudDx: 10,
          gloom: 0.5,
          sun: 0.2,
          bubble: 1,
          trail: 1,
          bg: const Color(0xFFEBEAF6),
        );
      case StickSceneKind.threeThings:
        // Her hand lifts a little as each one pops up.
        var bump = 0.0;
        for (var k = 0; k < 3; k++) {
          final d = (sec - (0.6 + 0.9 * k)) / 0.16;
          bump += math.exp(-d * d);
        }
        return _Stage(
          hipX: 112,
          hipY: 117,
          lean: 0.08 + 0.01 * breath,
          headTilt: -0.12,
          armNU: 1.15,
          armNF: 2.75 + 0.2 * bump,
          armFU: 0.3,
          armFF: 1.1,
          legNU: 1.45,
          legNF: 0.05,
          legFU: 1.36,
          legFF: -0.04,
          smile: 0.5,
          faceShift: 1,
          ponySway: 0.6 * breath,
          cloud: 0.25,
          cloudDx: 84,
          gloom: 0.15,
          sun: 0.5,
          trail: 1,
          items: [for (var k = 0; k < 3; k++) _pop(sec, 0.5 + 0.9 * k)],
          bg: const Color(0xFFF4EEF6),
        );
      case StickSceneKind.askWhy:
        return _Stage(
          hipX: 112,
          hipY: 117,
          lean: 0.1,
          headTilt: 0.04 + 0.1 * _wave(sec, 2),
          armNU: 0.85,
          armNF: 3.63,
          armFU: 0.3,
          armFF: 1.1,
          legNU: 1.45,
          legNF: 0.05,
          legFU: 1.36,
          legFF: -0.04,
          smile: 0.35,
          faceShift: 1,
          ponySway: _wave(sec, 2),
          cloudDx: 110,
          sun: 0.75,
          trail: 1,
          items: [
            for (var k = 0; k < 3; k++)
              1 + 0.16 * math.exp(-math.pow((sec - (0.5 + 1.2 * k)) / 0.22, 2)),
          ],
          question: 1,
          questionAt: _wave(sec, 2),
          bg: const Color(0xFFFBF1E6),
        );
      case StickSceneKind.everyEvening:
        return _Stage(
          hipX: 178,
          hipY: 100,
          lean: 0,
          headTilt: -0.05,
          armNU: 1.9,
          armNF: 2.6 + 0.4 * _wave(sec, 1),
          armFU: -0.18,
          armFF: -0.08,
          legNU: 0.1,
          legNF: 0.02,
          legFU: -0.1,
          legFF: -0.02,
          smile: 0.8,
          faceShift: 0.35,
          ponySway: _wave(sec, 1),
          cloudDx: 120,
          sun: 1,
          sunLow: 1,
          week: 1,
          weekFilled: ((sec - 0.3) / 0.45).clamp(0.0, 7.0),
          bg: const Color(0xFFFFEAD8),
        );
      case StickSceneKind.celebrate:
        // One jump a second.
        final p = sec % 1.0;
        final h = 4 * p * (1 - p);
        final wave = _wave(sec, 0.5);
        return _Stage(
          hipX: 168,
          hipY: 100 - 20 * h,
          lean: 0,
          headTilt: 0,
          armNU: 2.55 + 0.15 * wave,
          armNF: 2.95,
          armFU: -2.55 - 0.15 * wave,
          armFF: -2.95,
          legNU: 0.3 + 0.25 * h,
          legNF: -0.1 - 0.5 * h,
          legFU: -0.3 - 0.25 * h,
          legFF: 0.1 + 0.5 * h,
          smile: 1,
          faceShift: 0,
          ponyLift: math.max(0.0, 2 * p - 1),
          ponySway: wave,
          cloudDx: 120,
          sun: 1,
          bench: 0.3,
          sparkles: 1,
          bg: const Color(0xFFFFF3CF),
        );
    }
  }

  static _Stage lerp(_Stage a, _Stage b, double t) {
    if (t >= 1) return b;
    if (t <= 0) return a;
    double l(double x, double y) => lerpDouble(x, y, t)!;
    return _Stage(
      hipX: l(a.hipX, b.hipX),
      hipY: l(a.hipY, b.hipY),
      lean: l(a.lean, b.lean),
      headTilt: l(a.headTilt, b.headTilt),
      armNU: l(a.armNU, b.armNU),
      armNF: l(a.armNF, b.armNF),
      armFU: l(a.armFU, b.armFU),
      armFF: l(a.armFF, b.armFF),
      legNU: l(a.legNU, b.legNU),
      legNF: l(a.legNF, b.legNF),
      legFU: l(a.legFU, b.legFU),
      legFF: l(a.legFF, b.legFF),
      smile: l(a.smile, b.smile),
      faceShift: l(a.faceShift, b.faceShift),
      ponyLift: l(a.ponyLift, b.ponyLift),
      ponySway: l(a.ponySway, b.ponySway),
      rain: l(a.rain, b.rain),
      cloud: l(a.cloud, b.cloud),
      cloudDx: l(a.cloudDx, b.cloudDx),
      gloom: l(a.gloom, b.gloom),
      sun: l(a.sun, b.sun),
      sunLow: l(a.sunLow, b.sunLow),
      bench: l(a.bench, b.bench),
      bubble: l(a.bubble, b.bubble),
      trail: l(a.trail, b.trail),
      items: [for (var k = 0; k < 3; k++) l(a.items[k], b.items[k])],
      question: l(a.question, b.question),
      questionAt: b.questionAt,
      week: l(a.week, b.week),
      weekFilled: l(a.weekFilled, b.weekFilled),
      sparkles: l(a.sparkles, b.sparkles),
      bg: Color.lerp(a.bg, b.bg, t)!,
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.s, this.sec);

  final _Stage s;
  final double sec;

  /// The drawing is laid out on a 240 x 180 board, then scaled to fit.
  static const _board = Size(240, 180);
  static const _ground = 150.0;
  static const _ink = AppColors.ink;
  static const _itemAt = [Offset(160, 48), Offset(190, 30), Offset(218, 50)];

  static Offset _dir(double a) => Offset(math.sin(a), math.cos(a));

  static Offset _rot(Offset v, double a) => Offset(
    v.dx * math.cos(a) - v.dy * math.sin(a),
    v.dx * math.sin(a) + v.dy * math.cos(a),
  );

  /// A steady pseudo-random number in 0..1 for drop [i].
  static double _rand(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      Paint()..color = s.bg,
    );
    final scale = math.min(
      size.width / _board.width,
      size.height / _board.height,
    );
    canvas
      ..save()
      ..clipRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      )
      ..translate(
        (size.width - _board.width * scale) / 2,
        (size.height - _board.height * scale) / 2,
      )
      ..scale(scale);

    _sun(canvas);
    _cloud(canvas);
    _groundLine(canvas);
    _benchBack(canvas);
    _rain(canvas);
    final head = _girl(canvas);
    _thoughts(canvas, head);
    _weekDots(canvas);
    _sparkles(canvas);
    canvas.restore();
  }

  void _sun(Canvas canvas) {
    if (s.sun <= 0.01) return;
    final c = Offset(36, lerpDouble(30, 56, s.sunLow)!);
    final color = Color.lerp(
      const Color(0xFFF7C23E),
      const Color(0xFFF2873A),
      s.sunLow,
    )!.withValues(alpha: s.sun.clamp(0.0, 1.0));
    final r = 13.0 * (0.6 + 0.4 * s.sun);
    canvas.drawCircle(c, r, Paint()..color = color);
    final ray = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final turn = sec / 4 * (2 * math.pi / 8);
    for (var i = 0; i < 8; i++) {
      final d = _dir(turn + i * math.pi / 4);
      canvas.drawLine(c + d * (r + 5), c + d * (r + 10), ray);
    }
  }

  void _cloud(Canvas canvas) {
    if (s.cloud <= 0.01) return;
    final c = Offset(134 + s.cloudDx, 24);
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFFD5DBE8),
        const Color(0xFF8590A8),
        s.gloom,
      )!.withValues(alpha: s.cloud.clamp(0.0, 1.0));
    final path = Path()
      ..addOval(Rect.fromCircle(center: c + const Offset(-18, 4), radius: 11))
      ..addOval(Rect.fromCircle(center: c + const Offset(-3, -3), radius: 15))
      ..addOval(Rect.fromCircle(center: c + const Offset(14, 1), radius: 12))
      ..addOval(Rect.fromCircle(center: c + const Offset(27, 6), radius: 8))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(c.dx - 28, c.dy + 3, c.dx + 34, c.dy + 15),
          const Radius.circular(7),
        ),
      );
    canvas.drawPath(path, paint);
  }

  void _groundLine(Canvas canvas) {
    canvas.drawLine(
      const Offset(22, _ground + 2),
      const Offset(218, _ground + 2),
      Paint()
        ..color = _ink.withValues(alpha: 0.12)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (s.rain <= 0.05) return;
    // Ripples where the rain lands.
    for (var i = 0; i < 3; i++) {
      final p = (sec / 2 + i / 3) % 1.0;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(const [64.0, 156.0, 200.0][i], _ground + 3),
          width: 6 + 16 * p,
          height: 2 + 3 * p,
        ),
        Paint()
          ..color = const Color(
            0xFF6FA0E0,
          ).withValues(alpha: s.rain * (1 - p) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _benchBack(Canvas canvas) {
    if (s.bench <= 0.01) return;
    final wood = Paint()
      ..color = const Color(0xFFB98A5E).withValues(alpha: s.bench);
    final dark = Paint()
      ..color = const Color(0xFF8E6742).withValues(alpha: s.bench);
    RRect plank(double top) => RRect.fromRectAndRadius(
      Rect.fromLTRB(40, top, 138, top + 7),
      const Radius.circular(3),
    );
    for (final x in [50.0, 123.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, 94, x + 5, _ground + 2),
          const Radius.circular(2),
        ),
        dark,
      );
    }
    canvas
      ..drawRRect(plank(94), wood)
      ..drawRRect(plank(120), wood);
  }

  void _rain(Canvas canvas) {
    if (s.rain <= 0.02) return;
    const drops = 26;
    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < drops; i++) {
      // Fewer drops as it eases.
      if (i / drops >= s.rain) continue;
      final x = 34 + _rand(i, 1) * 182 + s.cloudDx * 0.4;
      final falls = 2 + i % 3;
      final y = 40 + ((sec / 4 * falls + _rand(i, 2)) % 1.0) * (_ground - 46);
      paint.color = const Color(
        0xFF6FA0E0,
      ).withValues(alpha: 0.35 + 0.45 * _rand(i, 3));
      canvas.drawLine(Offset(x, y), Offset(x - 2.5, y + 9), paint);
    }
  }

  /// Draws her; returns where her head is (for the thought trail).
  Offset _girl(Canvas canvas) {
    const torso = 38.0, upperArm = 18.0, foreArm = 17.0;
    const thigh = 24.0, shin = 26.0, headR = 12.0;
    final hip = Offset(s.hipX, s.hipY);
    final up = Offset(math.sin(s.lean), -math.cos(s.lean));
    final shoulder = hip + up * torso;
    final headAngle = s.lean + s.headTilt;
    final head =
        shoulder +
        Offset(math.sin(headAngle), -math.cos(headAngle)) * (headR + 4);

    final near = Paint()
      ..color = _ink
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final far = Paint()
      ..color = Color.lerp(s.bg, _ink, 0.55)!
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void limb(
      Offset from,
      double a1,
      double l1,
      double a2,
      double l2,
      Paint p,
    ) {
      final mid = from + _dir(a1) * l1;
      final end = mid + _dir(a2) * l2;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(mid.dx, mid.dy)
          ..lineTo(end.dx, end.dy),
        p,
      );
    }

    // Behind her: the far leg and arm.
    limb(hip, s.legFU, thigh, s.legFF, shin, far);
    limb(shoulder, s.armFU, upperArm, s.armFF, foreArm, far);

    // Ponytail, from the back of her head.
    final tailBase = head + _rot(const Offset(-10, -5), headAngle * 0.4);
    final tailEnd =
        tailBase + Offset(-11 - 3 * s.ponySway, 17 - 30 * s.ponyLift);
    final tailMid = tailBase + Offset(-15, 3 - 12 * s.ponyLift);
    canvas.drawPath(
      Path()
        ..moveTo(tailBase.dx, tailBase.dy)
        ..quadraticBezierTo(tailMid.dx, tailMid.dy, tailEnd.dx, tailEnd.dy),
      near,
    );

    // Body.
    canvas.drawLine(hip, shoulder, near);
    limb(hip, s.legNU, thigh, s.legNF, shin, near);

    // Skirt, draping along her legs.
    final legs = (_dir(s.legNU) + _dir(s.legFU)) / 2;
    final sitting = legs.dx.clamp(0.0, 1.0);
    final waist = hip + up * 10;
    final p1 = Offset(-up.dy, up.dx);
    final knee = hip + legs * 18;
    Offset mix(Offset standing, Offset seated) =>
        Offset.lerp(standing, seated, sitting)!;
    final front = waist + p1 * 5, back = waist - p1 * 5;
    final hemFront = mix(hip - up * 14 + p1 * 12, knee + const Offset(0, 8));
    final hemBack = mix(hip - up * 14 - p1 * 12, hip + const Offset(-7, 7));
    final lap = mix(
      Offset.lerp(front, hemFront, 0.5)!,
      knee + const Offset(0, -5),
    );
    final skirt = Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(lap.dx, lap.dy)
      ..lineTo(hemFront.dx, hemFront.dy)
      ..lineTo(hemBack.dx, hemBack.dy)
      ..lineTo(back.dx, back.dy)
      ..close();
    canvas
      ..drawPath(skirt, Paint()..color = AppColors.lavender)
      ..drawPath(
        skirt,
        Paint()
          ..color = AppColors.lavender
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round,
      );

    // Head, with a small bow where the ponytail starts.
    canvas
      ..drawCircle(head, headR, Paint()..color = AppColors.white)
      ..drawCircle(
        head,
        headR,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      )
      ..drawCircle(tailBase, 3.2, Paint()..color = const Color(0xFFE85D9A));

    // Face.
    Offset onFace(double x, double y) => head + _rot(Offset(x, y), headAngle);
    final dot = Paint()..color = _ink;
    canvas
      ..drawCircle(onFace(-3.5 + 4 * s.faceShift, -2), 1.5, dot)
      ..drawCircle(onFace(3.5 + 2 * s.faceShift, -2), 1.5, dot);
    final mx = 3 * s.faceShift;
    final m0 = onFace(mx - 3.6, 5), m1 = onFace(mx + 3.6, 5);
    final mc = onFace(mx, 5 + 4.5 * s.smile);
    canvas.drawPath(
      Path()
        ..moveTo(m0.dx, m0.dy)
        ..quadraticBezierTo(mc.dx, mc.dy, m1.dx, m1.dy),
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // In front: the near arm.
    limb(shoulder, s.armNU, upperArm, s.armNF, foreArm, near);
    return head;
  }

  void _thoughts(Canvas canvas, Offset head) {
    final line = Paint()
      ..color = _ink.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    if (s.trail > 0.01) {
      const steps = [Offset(15, -13), Offset(24, -23), Offset(34, -31)];
      for (var i = 0; i < 3; i++) {
        final r = (2.2 + i) * s.trail;
        canvas
          ..drawCircle(head + steps[i], r, Paint()..color = AppColors.white)
          ..drawCircle(head + steps[i], r, line);
      }
    }
    if (s.bubble > 0.01) {
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(192, 40),
          width: 66 * s.bubble,
          height: 38 * s.bubble,
        ),
        const Radius.circular(19),
      );
      canvas
        ..drawRRect(box, Paint()..color = AppColors.white)
        ..drawRRect(box, line);
      for (var i = 0; i < 3; i++) {
        final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (sec - i * 0.25));
        canvas.drawCircle(
          Offset(178.0 + i * 14, 40),
          (2.4 + 1.8 * pulse) * s.bubble,
          Paint()
            ..color = AppColors.lavender.withValues(alpha: 0.5 + 0.5 * pulse),
        );
      }
    }
    for (var k = 0; k < 3; k++) {
      final size = s.items[k];
      if (size <= 0.01) continue;
      canvas
        ..save()
        ..translate(_itemAt[k].dx, _itemAt[k].dy)
        ..scale(size)
        ..drawCircle(Offset.zero, 14, Paint()..color = AppColors.white)
        ..drawCircle(Offset.zero, 14, line);
      switch (k) {
        case 0:
          _heart(canvas);
        case 1:
          _cup(canvas);
        default:
          _star(canvas);
      }
      canvas.restore();
    }
    if (s.question > 0.01) {
      final p = head + Offset(-3, -30 - 3 * s.questionAt);
      final ink = Paint()
        ..color = AppColors.lavender.withValues(alpha: s.question)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawPath(
          Path()
            ..moveTo(p.dx - 4, p.dy - 5)
            ..cubicTo(
              p.dx - 4,
              p.dy - 11,
              p.dx + 5,
              p.dy - 11,
              p.dx + 5,
              p.dy - 5,
            )
            ..cubicTo(p.dx + 5, p.dy - 1, p.dx, p.dy - 1, p.dx, p.dy + 3),
          ink,
        )
        ..drawCircle(
          p + const Offset(0, 8),
          1.8,
          Paint()..color = AppColors.lavender.withValues(alpha: s.question),
        );
    }
  }

  void _heart(Canvas canvas) {
    const r = 7.0;
    canvas.drawPath(
      Path()
        ..moveTo(0, r * 0.85)
        ..cubicTo(-r * 1.4, -r * 0.1, -r * 0.6, -r * 1.1, 0, -r * 0.3)
        ..cubicTo(r * 0.6, -r * 1.1, r * 1.4, -r * 0.1, 0, r * 0.85)
        ..close(),
      Paint()..color = const Color(0xFFF2545B),
    );
  }

  void _cup(Canvas canvas) {
    final cup = Paint()..color = const Color(0xFFE9804C);
    canvas
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTRB(-6, -2, 4, 7),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        cup,
      )
      ..drawArc(
        const Rect.fromLTRB(1, 0, 9, 6),
        -math.pi / 2,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFFE9804C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    final steam = Paint()
      ..color = _ink.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final x in [-3.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, -4)
          ..quadraticBezierTo(x + 2, -6, x, -8),
        steam,
      );
    }
  }

  void _star(Canvas canvas) {
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 8.5 : 3.8;
      final a = i * math.pi / 5 - math.pi / 2;
      final p = Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFF7C23E));
  }

  /// Seven evenings, ticking off one by one.
  void _weekDots(Canvas canvas) {
    if (s.week <= 0.01) return;
    for (var i = 0; i < 7; i++) {
      final c = Offset(64.0 + i * 15, 24);
      final fill = (s.weekFilled - i).clamp(0.0, 1.0);
      canvas
        ..drawCircle(
          c,
          5,
          Paint()..color = AppColors.white.withValues(alpha: s.week),
        )
        ..drawCircle(
          c,
          5,
          Paint()
            ..color = _ink.withValues(alpha: 0.2 * s.week)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      if (fill > 0) {
        canvas.drawCircle(
          c,
          5 * Curves.easeOutBack.transform(fill),
          Paint()..color = AppColors.mint.withValues(alpha: s.week),
        );
      }
    }
  }

  void _sparkles(Canvas canvas) {
    if (s.sparkles <= 0.01) return;
    const at = [
      Offset(118, 44),
      Offset(214, 36),
      Offset(104, 96),
      Offset(222, 92),
      Offset(140, 18),
      Offset(196, 126),
    ];
    for (var i = 0; i < at.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(2 * math.pi * sec + i * 1.7);
      final size = (3 + 5 * twinkle) * s.sparkles;
      final c = at[i];
      final path = Path()
        ..moveTo(c.dx, c.dy - size)
        ..lineTo(c.dx + size * 0.28, c.dy - size * 0.28)
        ..lineTo(c.dx + size, c.dy)
        ..lineTo(c.dx + size * 0.28, c.dy + size * 0.28)
        ..lineTo(c.dx, c.dy + size)
        ..lineTo(c.dx - size * 0.28, c.dy + size * 0.28)
        ..lineTo(c.dx - size, c.dy)
        ..lineTo(c.dx - size * 0.28, c.dy - size * 0.28)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = (i.isEven ? const Color(0xFFF7C23E) : AppColors.lavender)
              .withValues(alpha: s.sparkles),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
