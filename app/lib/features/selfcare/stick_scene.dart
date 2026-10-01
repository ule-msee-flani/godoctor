import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Moments acted out by a girl in a big blue jumper: one for each feeling,
/// and one for each step of the practices that go with them.
enum StickSceneKind {
  // Sad, and "Three good things".
  sadRain,
  thinkBack,
  threeThings,
  askWhy,
  everyEvening,

  /// Jumping for joy: happy, and the end of most practices.
  celebrate,

  // The other feelings.
  calmSit,
  okayStand,
  tiredNod,
  moodySwing,
  anxiousFidget,
  angryStomp,
  weatherSick,

  // "Reach out to someone".
  reachThink,
  reachMessage,
  reachListen,

  // "A 10-minute walk".
  walkStart,
  walkBreathe,
  walkWeek,

  // "Your wind-down hour".
  dimLights,
  slowTime,
  writeDown,
  quietRoom,
  asleep,

  // "Name it to tame it".
  noticeBody,
  nameFeeling,
  sayIt,
  riseAndFall,

  // "Pause and cool down".
  stopNow,
  stepBack,
  breatheOut,
  whatINeed,
  comeBack,
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
    StickSceneKind.calmSit =>
      'The girl sits cross-legged with her eyes closed, breathing slowly.',
    StickSceneKind.okayStand => 'The girl gives a small, easy shrug.',
    StickSceneKind.tiredNod => 'The girl nods off on a bench under the moon.',
    StickSceneKind.moodySwing =>
      'A cloud slides over the sun and away again, and the girl\'s mood '
          'follows.',
    StickSceneKind.anxiousFidget =>
      'The girl paces and wrings her hands, a tangle of worry over her head.',
    StickSceneKind.angryStomp => 'The girl stomps her foot, steaming.',
    StickSceneKind.weatherSick =>
      'The girl sits wrapped in a blanket with a thermometer, under a '
          'drizzling cloud.',
    StickSceneKind.reachThink => 'The girl thinks of a friend.',
    StickSceneKind.reachMessage => 'The girl sends messages from her phone.',
    StickSceneKind.reachListen =>
      'The girl listens on the phone, nodding and smiling.',
    StickSceneKind.walkStart => 'The girl sets off on an easy walk.',
    StickSceneKind.walkBreathe =>
      'The girl walks, swinging her arms and breathing deeply.',
    StickSceneKind.walkWeek => 'The girl walks on as the days of a week fill.',
    StickSceneKind.dimLights =>
      'The girl dims the lamp; her phone rests on the bed.',
    StickSceneKind.slowTime => 'The girl sits on her bed reading a book.',
    StickSceneKind.writeDown => 'The girl writes tomorrow\'s list on a pad.',
    StickSceneKind.quietRoom => 'The room is dark and quiet. The girl yawns.',
    StickSceneKind.asleep => 'The girl is asleep in bed under the moon.',
    StickSceneKind.noticeBody =>
      'The girl closes her eyes, a hand on her chest.',
    StickSceneKind.nameFeeling =>
      'The girl looks over a few feelings to find the right one.',
    StickSceneKind.sayIt => 'The girl says the feeling out loud.',
    StickSceneKind.riseAndFall =>
      'The feeling drifts away on a wave as the girl smiles.',
    StickSceneKind.stopNow => 'The girl holds up her hand and pauses.',
    StickSceneKind.stepBack => 'The girl steps back from what upset her.',
    StickSceneKind.breatheOut => 'The girl breathes out slowly, five times.',
    StickSceneKind.whatINeed => 'The girl wonders what she really needs.',
    StickSceneKind.comeBack => 'The girl walks back, calm and smiling.',
  };
}

/// An animated illustrated scene, drawn live (no video, no image files).
/// Changing [scene] doesn't cut: she moves from one pose to the next and the
/// world changes around her.
class StickScene extends StatefulWidget {
  const StickScene({super.key, required this.scene, this.from, this.breath});

  final StickSceneKind scene;

  /// Where she starts when this first appears (then moves to [scene]).
  final StickSceneKind? from;

  /// For guided breathing ([StickSceneKind.calmSit]): how full her breath
  /// is, 0..1, so she breathes with the exercise instead of on her own.
  final double? breath;

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
            final to = _Stage.at(widget.scene, sec, widget.breath);
            return CustomPaint(
              size: Size.infinite,
              painter: _ScenePainter(
                t >= 1
                    ? to
                    : _Stage.lerp(_Stage.at(_prev, sec, widget.breath), to, t),
                sec,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Everything that can change, as numbers (so one scene can ease into the
/// next). Angles are from straight down, positive towards the right.
enum _P {
  // Her body. Near = the arm and leg in front; far = behind.
  hipX,
  hipY,
  lean,
  headTilt,
  armNU,
  armNF,
  armFU,
  armFF,
  legNU,
  legNF,
  legFU,
  legFF,
  // Her face. smile: -1 frown .. 1 smile; faceShift: 1 facing right .. 0
  // facing us; eyes: 1 open .. 0 closed.
  smile,
  faceShift,
  eyes,
  eyesWide,
  mouthOpen,
  brow,
  hot,
  ponyLift,
  ponySway,
  // Sky and weather.
  rain,
  rainSpan,
  cloud,
  cloudDx,
  gloom,
  sun,
  sunLow,
  moon,
  stars,
  // Things around her.
  bench,
  bed,
  lamp,
  lampGlow,
  tree,
  stride,
  // Thoughts and words.
  bubble,
  bubbleDots,
  bubbleHeart,
  friend,
  trail,
  item0,
  item1,
  item2,
  question,
  questionBob,
  feelings,
  feelingAt,
  speech,
  tide,
  week,
  weekCount,
  weekFilled,
  sparkles,
  // Feelings made visible.
  zzz,
  steam,
  scribble,
  sweat,
  glow,
  glowHot,
  aura,
  auraSize,
  // Things she holds or wears.
  phone,
  phoneRest,
  messages,
  incoming,
  sound,
  blanket,
  tucked,
  thermo,
  book,
  writing,
  note,
  noteLines,
  pause,
  trigger,
  puff,
  dust,
}

class _Stage {
  const _Stage(this.v, this.bg);

  factory _Stage.of(int bg, Map<_P, double> values) {
    final v = List<double>.of(_defaults);
    values.forEach((p, x) => v[p.index] = x);
    return _Stage(v, Color(bg));
  }

  final List<double> v;
  final Color bg;

  double operator [](_P p) => v[p.index];

  static final List<double> _defaults = () {
    final d = List<double>.filled(_P.values.length, 0);
    d[_P.hipX.index] = 120;
    d[_P.hipY.index] = 100;
    d[_P.faceShift.index] = 1;
    d[_P.eyes.index] = 1;
    d[_P.rainSpan.index] = 182;
    d[_P.bubbleDots.index] = 1;
    d[_P.weekCount.index] = 7;
    return d;
  }();

  /// These don't ease: the new scene's value is used at once.
  static const _snap = {_P.feelingAt, _P.weekCount, _P.rainSpan};

  /// Arm angles: when two are nearly a full turn apart, go the short way
  /// round rather than windmilling.
  static const _angles = {_P.armNU, _P.armNF, _P.armFU, _P.armFF};

  static double _wave(double sec, double period) =>
      math.sin(2 * math.pi * sec / period);

  static double _bell(double x, double centre, double width) {
    final d = (x - centre) / width;
    return math.exp(-d * d);
  }

  static double _pop(double sec, double at) {
    final x = ((sec - at) / 0.4).clamp(0.0, 1.0);
    final out = 1 - ((sec - 3.6) / 0.35).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(x) * out;
  }

  static const _sitBench = <_P, double>{
    _P.hipX: 112,
    _P.hipY: 117,
    _P.legNU: 1.45,
    _P.legNF: 0.02,
    _P.legFU: 1.36,
    _P.legFF: -0.06,
    _P.bench: 1,
  };

  static const _sitBed = <_P, double>{
    _P.hipX: 128,
    _P.hipY: 121,
    _P.legNU: 1.45,
    _P.legNF: 0.02,
    _P.legFU: 1.36,
    _P.legFF: -0.06,
    _P.bed: 1,
    _P.lamp: 1,
    _P.phoneRest: 1,
  };

  static Map<_P, double> _stand(double x) => {
    _P.hipX: x,
    _P.hipY: 100,
    _P.legNU: 0.1,
    _P.legNF: 0.02,
    _P.legFU: -0.1,
    _P.legFF: -0.02,
  };

  /// Walking on the spot while the ground goes by.
  static Map<_P, double> _walk(double x, double swing, double sec) {
    final c = _wave(sec, 1);
    return {
      _P.hipX: x,
      _P.hipY: 100 - 1.5 * _wave(sec, 0.5).abs(),
      _P.lean: 0.04,
      _P.legNU: 0.42 * c,
      _P.legNF: 0.42 * c - 0.15 * (1 - c),
      _P.legFU: -0.42 * c,
      _P.legFF: -0.42 * c - 0.15 * (1 + c),
      _P.armNU: -0.5 * c * swing,
      _P.armNF: -0.5 * c * swing + 0.35,
      _P.armFU: 0.5 * c * swing,
      _P.armFF: 0.5 * c * swing + 0.35,
      _P.stride: 1,
      _P.ponySway: c,
    };
  }

  /// The scene [kind], [sec] seconds into the four-second loop.
  static _Stage at(StickSceneKind kind, double sec, double? breath) {
    final slow = _wave(sec, 4);
    switch (kind) {
      case StickSceneKind.sadRain:
        // Little sobs, in bursts.
        final burst = math.max(0.0, slow);
        final sob = _wave(sec, 0.5) * burst * burst;
        return _Stage.of(0xFFE2E5F1, {
          ..._sitBench,
          _P.lean: 0.42 + 0.02 * slow,
          _P.headTilt: 0.55 + 0.04 * sob,
          _P.armNU: 0.5,
          _P.armNF: -1.9 + 0.04 * sob,
          _P.armFU: 0.75,
          _P.armFF: -1.6,
          _P.legNF: -0.22,
          _P.legFF: -0.3,
          _P.smile: -1,
          _P.ponySway: 0.4 * slow,
          _P.rain: 1,
          _P.cloud: 1,
          _P.gloom: 1,
        });
      case StickSceneKind.thinkBack:
        return _Stage.of(0xFFEBEAF6, {
          ..._sitBench,
          _P.lean: 0.2 + 0.015 * slow,
          _P.headTilt: -0.22 + 0.06 * slow,
          _P.armNU: 0.35,
          _P.armNF: 1.15,
          _P.armFU: 0.25,
          _P.armFF: 1.05,
          _P.legNF: 0,
          _P.legFF: -0.08,
          _P.smile: -0.15,
          _P.ponySway: 0.6 * slow,
          _P.rain: 0.22,
          _P.cloud: 0.85,
          _P.cloudDx: 10,
          _P.gloom: 0.5,
          _P.sun: 0.2,
          _P.bubble: 1,
          _P.trail: 1,
        });
      case StickSceneKind.threeThings:
        // Her hand lifts a little as each one pops up.
        var bump = 0.0;
        for (var k = 0; k < 3; k++) {
          bump += _bell(sec, 0.6 + 0.9 * k, 0.16);
        }
        return _Stage.of(0xFFF4EEF6, {
          ..._sitBench,
          _P.lean: 0.08 + 0.01 * slow,
          _P.headTilt: -0.12,
          _P.armNU: 1.15,
          _P.armNF: 2.75 + 0.2 * bump,
          _P.armFU: 0.3,
          _P.armFF: 1.1,
          _P.legNF: 0.05,
          _P.legFF: -0.04,
          _P.smile: 0.5,
          _P.ponySway: 0.6 * slow,
          _P.cloud: 0.25,
          _P.cloudDx: 84,
          _P.gloom: 0.15,
          _P.sun: 0.5,
          _P.trail: 1,
          _P.item0: _pop(sec, 0.5),
          _P.item1: _pop(sec, 1.4),
          _P.item2: _pop(sec, 2.3),
        });
      case StickSceneKind.askWhy:
        return _Stage.of(0xFFFBF1E6, {
          ..._sitBench,
          _P.lean: 0.1,
          _P.headTilt: 0.04 + 0.1 * _wave(sec, 2),
          _P.armNU: 0.85,
          _P.armNF: 3.63,
          _P.armFU: 0.3,
          _P.armFF: 1.1,
          _P.legNF: 0.05,
          _P.legFF: -0.04,
          _P.smile: 0.35,
          _P.ponySway: _wave(sec, 2),
          _P.cloudDx: 110,
          _P.sun: 0.75,
          _P.trail: 1,
          // Each one gets a turn.
          _P.item0: 1 + 0.16 * _bell(sec, 0.5, 0.22),
          _P.item1: 1 + 0.16 * _bell(sec, 1.7, 0.22),
          _P.item2: 1 + 0.16 * _bell(sec, 2.9, 0.22),
          _P.question: 1,
          _P.questionBob: _wave(sec, 2),
        });
      case StickSceneKind.everyEvening:
        return _Stage.of(0xFFFFEAD8, {
          ..._stand(178),
          _P.headTilt: -0.05,
          _P.armNU: 1.9,
          _P.armNF: 2.6 + 0.4 * _wave(sec, 1),
          _P.armFU: -0.18,
          _P.armFF: -0.08,
          _P.smile: 0.8,
          _P.faceShift: 0.35,
          _P.ponySway: _wave(sec, 1),
          _P.cloudDx: 120,
          _P.sun: 1,
          _P.sunLow: 1,
          _P.bench: 1,
          _P.week: 1,
          _P.weekFilled: ((sec - 0.3) / 0.45).clamp(0.0, 7.0),
        });
      case StickSceneKind.celebrate:
        // One jump a second.
        final p = sec % 1.0;
        final h = 4 * p * (1 - p);
        final wave = _wave(sec, 0.5);
        return _Stage.of(0xFFFFF3CF, {
          _P.hipX: 150,
          _P.hipY: 100 - 20 * h,
          _P.armNU: 2.55 + 0.15 * wave,
          _P.armNF: 2.95,
          _P.armFU: -2.55 - 0.15 * wave,
          _P.armFF: -2.95,
          _P.legNU: 0.3 + 0.25 * h,
          _P.legNF: -0.1 - 0.5 * h,
          _P.legFU: -0.3 - 0.25 * h,
          _P.legFF: 0.1 + 0.5 * h,
          _P.smile: 1,
          _P.faceShift: 0,
          _P.ponyLift: math.max(0.0, 2 * p - 1),
          _P.ponySway: wave,
          _P.cloudDx: 120,
          _P.sun: 1,
          _P.sparkles: 1,
        });
      case StickSceneKind.calmSit:
        final b = breath ?? 0.5 + 0.5 * slow;
        return _Stage.of(0xFFE6F3F0, {
          _P.hipX: 120,
          _P.hipY: 126 - 1.5 * b,
          _P.faceShift: 0,
          _P.eyes: 0,
          _P.smile: 0.5,
          _P.legNU: 1.0,
          _P.legNF: -1.15,
          _P.legFU: -1.0,
          _P.legFF: 1.15,
          _P.armNU: 0.25,
          _P.armNF: -0.5,
          _P.armFU: -0.25,
          _P.armFF: 0.5,
          _P.aura: 1,
          _P.auraSize: b,
          _P.sun: 0.6,
          _P.ponySway: 0.3 * slow,
        });
      case StickSceneKind.okayStand:
        final w = _wave(sec, 2);
        return _Stage.of(0xFFF3F1EA, {
          ..._stand(150),
          _P.hipY: 100 - 0.8 * math.max(0.0, w),
          _P.faceShift: 0.2,
          _P.smile: 0.25,
          _P.armNU: 0.5,
          _P.armNF: 1.9 + 0.14 * w,
          _P.armFU: -0.5,
          _P.armFF: -1.9 - 0.14 * w,
          _P.sun: 0.7,
          _P.cloud: 0.55,
          _P.cloudDx: -82,
          _P.ponySway: w,
        });
      case StickSceneKind.tiredNod:
        // Her head sinks slowly, then jerks back up.
        final t = sec / 4;
        final droop = t < 0.8 ? (t / 0.8) * (t / 0.8) : 1 - (t - 0.8) / 0.2;
        return _Stage.of(0xFFD8D9F0, {
          ..._sitBench,
          _P.lean: 0.25,
          _P.headTilt: 0.1 + 0.5 * droop,
          _P.eyes: 1 - droop,
          _P.armNU: 0.35,
          _P.armNF: 1.15,
          _P.armFU: 0.25,
          _P.armFF: 1.05,
          _P.smile: -0.2,
          _P.zzz: 1,
          _P.moon: 1,
          _P.stars: 1,
          _P.ponySway: 0.3 * slow,
        });
      case StickSceneKind.moodySwing:
        // Up and down with the weather over her.
        final up = (slow + 1) / 2;
        return _Stage(
          _Stage.of(0, {
            ..._stand(150),
            _P.faceShift: 0.2,
            _P.headTilt: 0.12 * (1 - up),
            _P.smile: 0.7 * slow,
            _P.armNU: 0.4 + 0.5 * up,
            _P.armNF: 1.2 + 1.2 * up,
            _P.armFU: -0.4 - 0.5 * up,
            _P.armFF: -1.2 - 1.2 * up,
            _P.sun: 0.95,
            _P.cloud: 0.95,
            _P.gloom: 0.45,
            _P.cloudDx: -98 + 62 * up,
            _P.rain: math.max(0.0, 0.4 - up) * 1.2,
            _P.rainSpan: 56,
            _P.ponySway: slow,
          }).v,
          Color.lerp(const Color(0xFFE6E6F3), const Color(0xFFFFF1D6), up)!,
        );
      case StickSceneKind.anxiousFidget:
        final jit = _wave(sec, 0.25);
        final step = _wave(sec, 1);
        return _Stage.of(0xFFE8F1EE, {
          _P.hipX: 140 + 9 * slow,
          _P.hipY: 100,
          _P.lean: 0.06,
          _P.headTilt: 0.08,
          _P.faceShift: 0.7,
          _P.armNU: 0.6,
          _P.armNF: 2.6 + 0.12 * jit,
          _P.armFU: 0.45,
          _P.armFF: 2.75 - 0.12 * jit,
          _P.legNU: 0.16 * step,
          _P.legNF: 0.16 * step - 0.05,
          _P.legFU: -0.16 * step,
          _P.legFF: -0.16 * step - 0.05,
          _P.smile: -0.6,
          _P.eyesWide: 1,
          _P.scribble: 1,
          _P.sweat: 1,
          _P.glow: 1,
          _P.glowHot: 1,
          _P.ponySway: jit,
        });
      case StickSceneKind.angryStomp:
        // One stomp a second.
        final p = sec % 1.0;
        final lift = p < 0.5 ? math.sin(math.pi * p / 0.5) : 0.0;
        final slam = _bell(p, 0.55, 0.06);
        final shake = _wave(sec, 0.25);
        return _Stage.of(0xFFFBE4E0, {
          ..._stand(140),
          _P.hipY: 100 + 1.5 * slam,
          _P.faceShift: 0.6,
          _P.lean: 0.05,
          _P.headTilt: 0.12,
          _P.brow: 1,
          _P.hot: 1,
          _P.smile: -0.9,
          _P.armNU: -0.12 + 0.04 * shake,
          _P.armNF: -0.05,
          _P.armFU: 0.28 - 0.04 * shake,
          _P.armFF: 0.3,
          _P.legNU: 0.1 + 0.9 * lift,
          _P.legNF: 0.02 - 1.1 * lift,
          _P.steam: 1,
          _P.dust: slam,
          _P.ponySway: shake,
        });
      case StickSceneKind.weatherSick:
        final shiver = _wave(sec, 0.25);
        return _Stage.of(0xFFE3EAF0, {
          ..._sitBench,
          _P.hipX: 112 + 0.7 * shiver,
          _P.lean: 0.2,
          _P.headTilt: 0.2,
          _P.armNU: 0.3,
          _P.armNF: -1.2,
          _P.armFU: 0.4,
          _P.armFF: -1.0,
          _P.blanket: 1,
          _P.thermo: 1,
          _P.smile: -0.4,
          _P.eyes: 0.3,
          _P.cloud: 0.9,
          _P.gloom: 0.6,
          _P.rain: 0.3,
          _P.rainSpan: 70,
          _P.ponySway: 0.2 * slow,
        });
      case StickSceneKind.reachThink:
        return _Stage.of(0xFFFFF3D9, {
          ..._stand(110),
          _P.faceShift: 0.8,
          _P.headTilt: -0.08 + 0.05 * slow,
          _P.armNU: 0.85,
          _P.armNF: 3.63,
          _P.armFU: -0.1,
          _P.armFF: 0.1,
          _P.smile: 0.5,
          _P.bubble: 1,
          _P.bubbleDots: 0,
          _P.friend: 1,
          _P.trail: 1,
          _P.sun: 0.8,
          _P.ponySway: 0.5 * slow,
        });
      case StickSceneKind.reachMessage:
        return _Stage.of(0xFFFFF1DD, {
          ..._stand(110),
          _P.faceShift: 0.9,
          _P.headTilt: 0.2,
          _P.armNU: 0.7,
          _P.armNF: 2.5,
          _P.armFU: 0.55,
          _P.armFF: 2.35 + 0.1 * _wave(sec, 0.5),
          _P.smile: 0.6,
          _P.phone: 1,
          _P.messages: 1,
          _P.sun: 0.8,
        });
      case StickSceneKind.reachListen:
        return _Stage.of(0xFFFFF0DA, {
          ..._stand(110),
          _P.faceShift: 0.8,
          _P.headTilt: 0.04 + 0.07 * _wave(sec, 1),
          _P.armNU: 1.0,
          _P.armNF: 3.77,
          _P.armFU: -0.12,
          _P.armFF: 0.05,
          _P.smile: 0.85,
          _P.phone: 1,
          _P.sound: 1,
          _P.incoming: 1,
          _P.sun: 0.9,
          _P.ponySway: _wave(sec, 1),
        });
      case StickSceneKind.walkStart:
        return _Stage.of(0xFFEAF5EA, {
          ..._walk(120, 0.6, sec),
          _P.smile: 0.5,
          _P.sun: 0.8,
          _P.tree: 1,
        });
      case StickSceneKind.walkBreathe:
        return _Stage.of(0xFFE6F4EC, {
          ..._walk(120, 1.1, sec),
          _P.smile: 0.6,
          _P.puff: 1,
          _P.sun: 0.9,
          _P.tree: 1,
        });
      case StickSceneKind.walkWeek:
        return _Stage.of(0xFFEEF6E0, {
          ..._walk(120, 0.9, sec),
          _P.smile: 0.85,
          _P.week: 1,
          _P.weekFilled: ((sec - 0.3) / 0.45).clamp(0.0, 7.0),
          _P.sparkles: 0.45,
          _P.sun: 1,
          _P.tree: 1,
        });
      case StickSceneKind.dimLights:
        // The lamp goes from bright to low.
        final dim = Curves.easeInOut.transform((sec / 2.6).clamp(0.0, 1.0));
        return _Stage(
          _Stage.of(0, {
            ..._stand(168),
            _P.bed: 1,
            _P.lamp: 1,
            _P.lampGlow: 1 - 0.7 * dim,
            _P.phoneRest: 1,
            _P.faceShift: 0.9,
            _P.armNU: 1.7,
            _P.armNF: 1.9,
            _P.armFU: -0.15,
            _P.armFF: -0.05,
            _P.smile: 0.2,
            _P.moon: 0.4,
            _P.stars: 0.3,
          }).v,
          Color.lerp(const Color(0xFFFFF0D6), const Color(0xFFEADFD6), dim)!,
        );
      case StickSceneKind.slowTime:
        return _Stage.of(0xFFEBE1DC, {
          ..._sitBed,
          _P.lean: 0.12,
          _P.headTilt: 0.28 + 0.03 * slow,
          _P.armNU: 0.6,
          _P.armNF: 2.0,
          _P.armFU: 0.5,
          _P.armFF: 1.9,
          _P.book: 1,
          _P.lampGlow: 0.45,
          _P.smile: 0.4,
          _P.moon: 0.5,
          _P.stars: 0.4,
        });
      case StickSceneKind.writeDown:
        return _Stage.of(0xFFE6DEDF, {
          ..._sitBed,
          _P.lean: 0.14,
          _P.headTilt: 0.3,
          _P.armNU: 0.6,
          _P.armNF: 2.0 + 0.06 * _wave(sec, 0.25),
          _P.armFU: 0.5,
          _P.armFF: 1.9,
          _P.book: 1,
          _P.writing: 1,
          _P.note: 1,
          _P.noteLines: ((sec - 0.4) / 1.0).clamp(0.0, 3.0),
          _P.lampGlow: 0.4,
          _P.smile: 0.3,
          _P.moon: 0.6,
          _P.stars: 0.5,
        });
      case StickSceneKind.quietRoom:
        // One long yawn.
        final yawn = _bell(sec, 2, 0.5);
        return _Stage.of(0xFFD9DBEF, {
          ..._sitBed,
          _P.lean: 0.1,
          _P.headTilt: 0.05 - 0.1 * yawn,
          _P.armNU: 0.35 + 0.6 * yawn,
          _P.armNF: 1.15 + 2.4 * yawn,
          _P.armFU: 0.25,
          _P.armFF: 1.05,
          _P.mouthOpen: yawn,
          _P.eyes: 1 - yawn,
          _P.smile: 0.2,
          _P.lampGlow: 0.08,
          _P.moon: 1,
          _P.stars: 1,
        });
      case StickSceneKind.asleep:
        return _Stage.of(0xFFCDD0EA, {
          _P.hipX: 110,
          _P.hipY: 119 - 0.6 * slow,
          _P.lean: -1.5,
          _P.legNU: 1.5,
          _P.legNF: 1.5,
          _P.legFU: 1.46,
          _P.legFF: 1.5,
          _P.armNU: 1.4,
          _P.armNF: 1.45,
          _P.armFU: 1.35,
          _P.armFF: 1.4,
          _P.eyes: 0,
          _P.smile: 0.4,
          _P.bed: 1,
          _P.lamp: 1,
          _P.phoneRest: 1,
          _P.blanket: 1,
          _P.tucked: 1,
          _P.zzz: 1,
          _P.moon: 1,
          _P.stars: 1,
        });
      case StickSceneKind.noticeBody:
        return _Stage.of(0xFFEDEAF6, {
          ..._stand(130),
          _P.faceShift: 0.1,
          _P.eyes: 0,
          _P.armNU: 0.8,
          _P.armNF: -2.0,
          _P.armFU: -0.2,
          _P.armFF: -0.1,
          _P.glow: 1,
          _P.sun: 0.5,
          _P.cloud: 0.4,
          _P.cloudDx: -60,
          _P.ponySway: 0.3 * slow,
        });
      case StickSceneKind.nameFeeling:
        return _Stage.of(0xFFEFEBF5, {
          ..._stand(130),
          _P.faceShift: 0.7,
          _P.headTilt: -0.05 + 0.05 * _wave(sec, 2),
          _P.armNU: 0.85,
          _P.armNF: 3.63,
          _P.armFU: -0.15,
          _P.armFF: 0,
          _P.feelings: 1,
          _P.feelingAt: (sec / (4 / 3)).floorToDouble() % 3,
          _P.trail: 1,
          _P.smile: 0.1,
          _P.sun: 0.55,
          _P.cloud: 0.3,
          _P.cloudDx: -60,
        });
      case StickSceneKind.sayIt:
        return _Stage.of(0xFFF2EDF3, {
          ..._stand(130),
          _P.faceShift: 0.8,
          _P.armNU: 1.0,
          _P.armNF: 2.3 + 0.15 * _wave(sec, 1),
          _P.armFU: -0.15,
          _P.armFF: 0,
          _P.mouthOpen: 0.3 + 0.3 * _wave(sec, 0.5),
          _P.speech: 1,
          _P.smile: 0.2,
          _P.sun: 0.65,
        });
      case StickSceneKind.riseAndFall:
        return _Stage.of(0xFFFBF2E4, {
          ..._stand(130),
          _P.faceShift: 0.4,
          _P.armNU: 0.5,
          _P.armNF: 0.9,
          _P.armFU: -0.5,
          _P.armFF: -0.9,
          _P.smile: 0.7,
          _P.tide: 1,
          _P.sun: 0.9,
          _P.ponySway: _wave(sec, 2),
        });
      case StickSceneKind.stopNow:
        return _Stage.of(0xFFFBE7E0, {
          ..._stand(140),
          _P.faceShift: 0.8,
          _P.brow: 0.8,
          _P.hot: 0.8,
          _P.smile: -0.7,
          _P.armNU: 1.45,
          _P.armNF: 2.9,
          _P.armFU: -0.1,
          _P.armFF: -0.05,
          _P.pause: 1,
          _P.steam: 0.35,
        });
      case StickSceneKind.stepBack:
        final c = _wave(sec, 1);
        return _Stage.of(0xFFF8EAE4, {
          _P.hipX: 98,
          _P.hipY: 100,
          _P.lean: -0.05,
          _P.legNU: -0.2 * c,
          _P.legNF: -0.2 * c - 0.08,
          _P.legFU: 0.2 * c,
          _P.legFF: 0.2 * c - 0.08,
          _P.faceShift: 0.9,
          _P.brow: 0.45,
          _P.hot: 0.5,
          _P.smile: -0.45,
          _P.armNU: 1.0,
          _P.armNF: 2.4,
          _P.armFU: 0.7,
          _P.armFF: 2.2,
          _P.trigger: 1,
          _P.steam: 0.12,
        });
      case StickSceneKind.breatheOut:
        return _Stage.of(0xFFF3ECE8, {
          ..._stand(98),
          _P.faceShift: 0.8,
          _P.eyes: 0,
          _P.brow: 0.1,
          _P.hot: 0.2,
          _P.smile: -0.05,
          _P.armNU: 0.15,
          _P.armNF: 0.1,
          _P.armFU: -0.1,
          _P.armFF: -0.05,
          _P.puff: 1,
          _P.trigger: 0.3,
          _P.week: 1,
          _P.weekCount: 5,
          _P.weekFilled: ((sec - 0.3) / 0.65).clamp(0.0, 5.0),
        });
      case StickSceneKind.whatINeed:
        return _Stage.of(0xFFF4EEEA, {
          ..._stand(98),
          _P.faceShift: 0.8,
          _P.headTilt: 0.04 + 0.08 * _wave(sec, 2),
          _P.armNU: 0.85,
          _P.armNF: 3.63,
          _P.armFU: -0.1,
          _P.armFF: 0,
          _P.bubble: 1,
          _P.bubbleDots: 0,
          _P.bubbleHeart: 1,
          _P.trail: 1,
          _P.question: 1,
          _P.questionBob: _wave(sec, 2),
          _P.smile: 0.25,
          _P.sun: 0.4,
        });
      case StickSceneKind.comeBack:
        return _Stage.of(0xFFFFF3DA, {
          ..._walk(150, 0.7, sec),
          _P.smile: 0.8,
          _P.sun: 0.9,
          _P.sparkles: 0.3,
        });
    }
  }

  static _Stage lerp(_Stage a, _Stage b, double t) {
    if (t >= 1) return b;
    if (t <= 0) return a;
    final v = List<double>.filled(_P.values.length, 0);
    for (final p in _P.values) {
      final i = p.index;
      var from = a.v[i];
      final to = b.v[i];
      if (_snap.contains(p)) {
        v[i] = to;
        continue;
      }
      if (_angles.contains(p) && (to - from).abs() > math.pi + 0.9) {
        from += (to > from ? 1 : -1) * 2 * math.pi;
      }
      v[i] = lerpDouble(from, to, t)!;
    }
    return _Stage(v, Color.lerp(a.bg, b.bg, t)!);
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
  static const _red = Color(0xFFF2545B);
  static const _blue = Color(0xFF6FA0E0);
  static const _woodDark = Color(0xFF8E6742);

  static Offset _dir(double a) => Offset(math.sin(a), math.cos(a));

  static Offset _rot(Offset v, double a) => Offset(
    v.dx * math.cos(a) - v.dy * math.sin(a),
    v.dx * math.sin(a) + v.dy * math.cos(a),
  );

  /// A steady pseudo-random number in 0..1 for thing [i].
  static double _rand(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  static Paint _line(Color c, double width) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static Paint _fill(Color c, [double alpha = 1]) =>
      Paint()..color = c.withValues(alpha: alpha.clamp(0.0, 1.0));

  static Paint get _thin => _line(_ink.withValues(alpha: 0.22), 1.5);

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(22),
    );
    canvas.drawRRect(frame, Paint()..color = s.bg);
    final scale = math.min(
      size.width / _board.width,
      size.height / _board.height,
    );
    canvas
      ..save()
      ..clipRRect(frame)
      ..translate(
        (size.width - _board.width * scale) / 2,
        (size.height - _board.height * scale) / 2,
      )
      ..scale(scale);

    _sun(canvas);
    _night(canvas);
    _cloud(canvas);
    _lamp(canvas);
    _tide(canvas);
    _groundLine(canvas);
    _bench(canvas);
    _bed(canvas);
    _rain(canvas);
    final g = _girl(canvas);
    _thoughts(canvas, g.head);
    _feelings(canvas, g.head);
    _speech(canvas, g.head);
    _aboveHead(canvas, g.head);
    _fromHand(canvas, g.hand);
    _breathOut(canvas, g.mouth);
    _note(canvas);
    _trigger(canvas);
    _weekDots(canvas);
    _sparkles(canvas);
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Sky and room
  // -------------------------------------------------------------------------

  void _sun(Canvas canvas) {
    final sun = s[_P.sun];
    if (sun <= 0.01) return;
    final low = s[_P.sunLow];
    final c = Offset(36, lerpDouble(30, 56, low)!);
    final color = Color.lerp(
      const Color(0xFFF7C23E),
      const Color(0xFFF2873A),
      low,
    )!.withValues(alpha: sun.clamp(0.0, 1.0));
    final r = 13.0 * (0.6 + 0.4 * sun);
    canvas.drawCircle(c, r, Paint()..color = color);
    final ray = _line(color, 3);
    final turn = sec / 4 * (2 * math.pi / 8);
    for (var i = 0; i < 8; i++) {
      final d = _dir(turn + i * math.pi / 4);
      canvas.drawLine(c + d * (r + 5), c + d * (r + 10), ray);
    }
  }

  void _night(Canvas canvas) {
    const gold = Color(0xFFF3DC8A);
    final moon = s[_P.moon];
    if (moon > 0.01) {
      const c = Offset(38, 30);
      canvas.drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: c, radius: 13)),
          Path()..addOval(
            Rect.fromCircle(center: c + const Offset(7, -4), radius: 11),
          ),
        ),
        _fill(gold, moon),
      );
    }
    final stars = s[_P.stars];
    if (stars <= 0.01) return;
    const at = [
      Offset(78, 20),
      Offset(112, 38),
      Offset(150, 16),
      Offset(176, 40),
      Offset(222, 22),
      Offset(60, 52),
    ];
    for (var i = 0; i < at.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(math.pi * sec / 2 + i * 2.1);
      canvas.drawCircle(
        at[i],
        1.2 + 1.2 * twinkle,
        _fill(gold, stars * (0.5 + 0.5 * twinkle)),
      );
    }
  }

  void _cloud(Canvas canvas) {
    final cloud = s[_P.cloud];
    if (cloud <= 0.01) return;
    final c = Offset(134 + s[_P.cloudDx], 24);
    canvas.drawPath(
      Path()
        ..addOval(Rect.fromCircle(center: c + const Offset(-18, 4), radius: 11))
        ..addOval(Rect.fromCircle(center: c + const Offset(-3, -3), radius: 15))
        ..addOval(Rect.fromCircle(center: c + const Offset(14, 1), radius: 12))
        ..addOval(Rect.fromCircle(center: c + const Offset(27, 6), radius: 8))
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(c.dx - 28, c.dy + 3, c.dx + 34, c.dy + 15),
            const Radius.circular(7),
          ),
        ),
      _fill(
        Color.lerp(
          const Color(0xFFD5DBE8),
          const Color(0xFF8590A8),
          s[_P.gloom],
        )!,
        cloud,
      ),
    );
  }

  void _lamp(Canvas canvas) {
    final lamp = s[_P.lamp];
    if (lamp <= 0.01) return;
    final glow = s[_P.lampGlow];
    if (glow > 0.01) {
      canvas.drawCircle(
        const Offset(208, 84),
        30 + 26 * glow,
        _fill(const Color(0xFFFFE08A), 0.45 * glow * lamp),
      );
    }
    final pole = _line(_woodDark.withValues(alpha: lamp), 3);
    canvas
      ..drawLine(const Offset(208, 76), const Offset(208, _ground + 1), pole)
      ..drawLine(
        const Offset(200, _ground + 1),
        const Offset(216, _ground + 1),
        pole,
      )
      ..drawPath(
        Path()
          ..moveTo(199, 58)
          ..lineTo(217, 58)
          ..lineTo(224, 77)
          ..lineTo(192, 77)
          ..close(),
        _fill(
          Color.lerp(const Color(0xFFC9B48A), const Color(0xFFF7D774), glow)!,
          lamp,
        ),
      );
  }

  /// A feeling is a wave: it rises, and it passes.
  void _tide(Canvas canvas) {
    final tide = s[_P.tide];
    if (tide <= 0.01) return;
    double y(double x) =>
        92 + 12 * math.sin(x / 200 * 3 * math.pi - sec * math.pi / 2);
    final path = Path()..moveTo(14, y(14));
    for (var x = 18.0; x <= 226; x += 4) {
      path.lineTo(x, y(x));
    }
    canvas.drawPath(
      path,
      _line(AppColors.lavender.withValues(alpha: 0.4 * tide), 3),
    );
    // The feeling she named rides it out of the picture.
    final p = (sec / 4) % 1.0;
    final x = 40 + 190 * p;
    _feelShape(
      canvas,
      2,
      Offset(x, y(x) - 9),
      0.9,
      tide * math.sin(math.pi * p),
    );
  }

  void _groundLine(Canvas canvas) {
    canvas.drawLine(
      const Offset(22, _ground + 2),
      const Offset(218, _ground + 2),
      _line(_ink.withValues(alpha: 0.12), 3),
    );
    final stride = s[_P.stride];
    if (stride > 0.01) {
      // The ground going by as she walks.
      final shift = (sec * 70) % 35;
      final mark = _line(_ink.withValues(alpha: 0.16 * stride), 2);
      for (var x = 65.0 - shift; x < 214; x += 35) {
        canvas.drawLine(
          Offset(x, _ground + 8),
          Offset(x + 9, _ground + 8),
          mark,
        );
      }
    }
    final tree = s[_P.tree];
    if (tree > 0.01) {
      const leaf = Color(0xFF6DBF8B);
      final x = 262 - (sec / 4) * 290;
      canvas
        ..drawLine(
          Offset(x, _ground),
          Offset(x, _ground - 22),
          _line(_woodDark.withValues(alpha: tree), 4),
        )
        ..drawCircle(Offset(x, _ground - 32), 13, _fill(leaf, tree))
        ..drawCircle(Offset(x + 8, _ground - 24), 9, _fill(leaf, tree));
    }
    final rain = s[_P.rain];
    if (rain > 0.05) {
      // Ripples where the rain lands.
      final middle = 134 + s[_P.cloudDx];
      final span = s[_P.rainSpan];
      for (var i = 0; i < 3; i++) {
        final p = (sec / 2 + i / 3) % 1.0;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              middle + const [-0.38, 0.12, 0.36][i] * span,
              _ground + 3,
            ),
            width: 6 + 16 * p,
            height: 2 + 3 * p,
          ),
          _line(_blue.withValues(alpha: rain * (1 - p) * 0.7), 1.4),
        );
      }
    }
  }

  void _bench(Canvas canvas) {
    final bench = s[_P.bench];
    if (bench <= 0.01) return;
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
        _fill(_woodDark, bench),
      );
    }
    final wood = _fill(const Color(0xFFB98A5E), bench);
    canvas
      ..drawRRect(plank(94), wood)
      ..drawRRect(plank(120), wood);
  }

  void _bed(Canvas canvas) {
    final bed = s[_P.bed];
    if (bed <= 0.01) return;
    RRect box(double l, double t, double r, double b, double radius) =>
        RRect.fromRectAndRadius(
          Rect.fromLTRB(l, t, r, b),
          Radius.circular(radius),
        );
    final dark = _fill(_woodDark, bed);
    final edge = _line(_ink.withValues(alpha: 0.18 * bed), 1.5);
    final mattress = box(38, 124, 153, 136, 5);
    final pillow = box(43, 114, 75, 125, 5);
    canvas
      ..drawRRect(box(32, 98, 40, _ground + 2, 3), dark)
      ..drawRRect(box(146, 136, 151, _ground + 2, 2), dark)
      ..drawRRect(box(38, 134, 153, 142, 3), dark)
      ..drawRRect(mattress, _fill(const Color(0xFFF7F4FC), bed))
      ..drawRRect(mattress, edge)
      ..drawRRect(pillow, _fill(AppColors.white, bed))
      ..drawRRect(pillow, edge);
    final rest = s[_P.phoneRest];
    if (rest > 0.01) {
      // Her phone, put away for the night.
      canvas.drawRRect(box(84, 120, 98, 124, 2), _fill(_ink, 0.75 * rest));
    }
  }

  void _rain(Canvas canvas) {
    final rain = s[_P.rain];
    if (rain <= 0.02) return;
    const drops = 26;
    final middle = 134 + s[_P.cloudDx];
    final span = s[_P.rainSpan];
    for (var i = 0; i < drops; i++) {
      // Fewer drops as it eases.
      if (i / drops >= rain) continue;
      final x = middle + (_rand(i, 1) - 0.5) * span;
      final falls = 2 + i % 3;
      final y = 40 + ((sec / 4 * falls + _rand(i, 2)) % 1.0) * (_ground - 46);
      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2.5, y + 9),
        _line(_blue.withValues(alpha: 0.35 + 0.45 * _rand(i, 3)), 2),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Her
  // -------------------------------------------------------------------------

  // Her look: an oversized blue jumper, a pink skirt peeking out, bright
  // socks and chunky boots, and a puff of hair.
  static const _skin = Color(0xFFB97852);
  static const _skinShade = Color(0xFF9A5F40);
  static const _hair = Color(0xFF2A1A14);
  static const _jumper = Color(0xFF5468D4);
  static const _jumperShade = Color(0xFF3F52BA);
  static const _jumperLight = Color(0xFF8496EE);
  static const _skirt = Color(0xFFF4A2BD);
  static const _sock = Color(0xFFFF5B2E);
  static const _sockShade = Color(0xFFD9461E);
  static const _boot = Color(0xFF1F1F2A);
  static const _sole = Color(0xFF4A4A5C);

  /// Draws her; returns where her head, near hand and mouth are.
  ({Offset head, Offset hand, Offset mouth}) _girl(Canvas canvas) {
    const torso = 38.0, upperArm = 18.0, foreArm = 17.0;
    const thigh = 24.0, shin = 21.0, headR = 10.5;
    final hip = Offset(s[_P.hipX], s[_P.hipY]);
    final lean = s[_P.lean];
    final up = Offset(math.sin(lean), -math.cos(lean));
    final side = Offset(-up.dy, up.dx);
    Offset body(double x, double y) => hip + up * y + side * x;
    final shoulder = hip + up * torso;
    final headAngle = lean + s[_P.headTilt];
    final head =
        shoulder +
        Offset(math.sin(headAngle), -math.cos(headAngle)) * (headR + 4);
    final shift = s[_P.faceShift];
    // Facing us, her arms and legs sit at the sides; side-on they line up.
    final front = 1 - shift;
    final nearShoulder = shoulder + side * (9 * front) - up * 3;
    final farShoulder = shoulder - side * (9 * front) - up * 3;
    final nearHip = hip + side * (5 * front);
    final farHip = hip - side * (5 * front);
    final tucked = s[_P.tucked] > 0.5;

    // Her shadow on the ground (smaller as she jumps).
    if (s[_P.bench] < 0.5 && s[_P.bed] < 0.5) {
      final lift = ((100 - hip.dy) / 24).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(hip.dx, _ground + 2),
          width: 46 * (1 - 0.35 * lift),
          height: 6 * (1 - 0.3 * lift),
        ),
        _fill(_ink, 0.1 * (1 - 0.5 * lift)),
      );
    }

    // A slow breathing ring behind her.
    final aura = s[_P.aura];
    if (aura > 0.01) {
      final c = hip - const Offset(0, 22);
      final r = 32 + 22 * s[_P.auraSize];
      canvas
        ..drawCircle(c, r, _fill(AppColors.mint, 0.14 * aura))
        ..drawCircle(
          c,
          r,
          _line(AppColors.mint.withValues(alpha: 0.45 * aura), 2),
        );
    }

    // Dust when she stomps.
    final dust = s[_P.dust];
    if (dust > 0.02) {
      final foot = Offset(hip.dx + 8, _ground);
      for (final d in [-1.0, 1.0]) {
        canvas.drawLine(
          foot + Offset(d * 8, -1),
          foot + Offset(d * (12 + 8 * dust), -4),
          _line(_ink.withValues(alpha: 0.35 * dust), 2),
        );
      }
    }

    void leg(Offset from, double a1, double a2, {required bool near}) {
      final knee = from + _dir(a1) * thigh;
      final d = _dir(a2);
      final ankle = knee + d * shin;
      final skin = near ? _skin : _skinShade;
      canvas
        ..drawLine(from, knee, _line(skin, 7.5))
        ..drawLine(knee, ankle, _line(skin, 6.5))
        // Bright socks.
        ..drawLine(
          Offset.lerp(knee, ankle, 0.35)!,
          ankle,
          _line(near ? _sock : _sockShade, 7.4),
        );
      // Chunky boots, toes forward (outwards when she faces us).
      final toeSign = near || shift > 0.5 ? 1.0 : -1.0;
      final toe = Offset(d.dy, -d.dx) * toeSign;
      canvas
        ..drawLine(ankle - d * 4, ankle + d * 1.5, _line(_boot, 10.5))
        ..drawLine(ankle + d * 2, ankle + d * 2 + toe * 7, _line(_boot, 9))
        ..drawLine(
          ankle + d * 6.2 - toe * 3.5,
          ankle + d * 6.2 + toe * 9.5,
          _line(_sole, 2.8),
        )
        ..drawCircle(ankle - d * 1.6 + toe * 2.4, 0.95, _fill(AppColors.white))
        ..drawCircle(ankle + d * 0.8 + toe * 4.4, 0.95, _fill(AppColors.white));
    }

    Offset arm(Offset from, double a1, double a2, {required bool near}) {
      final elbow = from + _dir(a1) * upperArm;
      final d = _dir(a2);
      final hand = elbow + d * foreArm;
      final wrist = elbow + d * (foreArm - 3.5);
      final sleeve = near ? _jumper : _jumperShade;
      canvas
        ..drawLine(from, elbow, _line(sleeve, 9.5))
        ..drawLine(elbow, wrist, _line(sleeve, 8.5))
        // A rolled cuff, then her hand.
        ..drawLine(
          wrist - d * 1.2,
          wrist + d * 0.6,
          _line(near ? _jumperLight : _jumper, 9.5),
        )
        ..drawCircle(hand, 3.5, _fill(near ? _skin : _skinShade));
      return hand;
    }

    // Behind her: the far leg and arm, and her puff of hair.
    leg(farHip, s[_P.legFU], s[_P.legFF], near: false);
    final farHand = arm(farShoulder, s[_P.armFU], s[_P.armFF], near: false);
    final lift = s[_P.ponyLift], sway = s[_P.ponySway];
    final bunAt =
        head +
        _rot(
          Offset.lerp(const Offset(0, -13), const Offset(-11.5, -6), shift)! +
              Offset(-2 * sway, -4 * lift),
          headAngle * 0.6,
        );
    // A bright tie where the puff meets her head (tucked behind it).
    final toHead = head - bunAt;
    canvas
      ..drawCircle(bunAt, 7, _fill(_hair))
      ..drawCircle(bunAt + toHead / toHead.distance * 6, 2.6, _fill(_sock));

    // A feeling in her chest.
    final glow = s[_P.glow];
    if (glow > 0.01) {
      final hot = s[_P.glowHot];
      final beat =
          0.5 + 0.5 * math.sin(2 * math.pi * sec / (hot > 0.5 ? 0.5 : 2));
      final c = body(0, 25);
      final color = Color.lerp(AppColors.lavender, _red, hot)!;
      canvas
        ..drawCircle(c, 13 + 6 * beat, _fill(color, 0.2 * glow))
        ..drawCircle(c, 8 + 3 * beat, _fill(color, 0.3 * glow));
    }

    leg(nearHip, s[_P.legNU], s[_P.legNF], near: true);

    // Skirt, peeking out under the jumper (over her lap when sitting).
    final legs = (_dir(s[_P.legNU]) + _dir(s[_P.legFU])) / 2;
    final sitting = (legs.dx.abs() * (tucked ? 0 : 1)).clamp(0.0, 1.0);
    final waist = hip + up * 6;
    final knee = hip + legs * 19;
    Offset mix(Offset standing, Offset seated) =>
        Offset.lerp(standing, seated, sitting)!;
    final skirtFront = waist + side * 9, skirtBack = waist - side * 9;
    final hemFront = mix(hip - up * 15 + side * 15, knee + const Offset(1, 7));
    final hemBack = mix(hip - up * 15 - side * 15, hip + const Offset(-9, 7));
    final lap = mix(
      Offset.lerp(skirtFront, hemFront, 0.5)!,
      knee + const Offset(0, -5),
    );
    if (!tucked) {
      final skirt = Path()
        ..moveTo(skirtFront.dx, skirtFront.dy)
        ..lineTo(lap.dx, lap.dy)
        ..lineTo(hemFront.dx, hemFront.dy)
        ..lineTo(hemBack.dx, hemBack.dy)
        ..lineTo(skirtBack.dx, skirtBack.dy)
        ..close();
      canvas
        ..drawPath(skirt, _fill(_skirt))
        ..drawPath(skirt, _line(_skirt, 3));
    }

    // The big comfy jumper.
    Path shape(List<Offset> pts) {
      final path = Path();
      for (final (i, q) in pts.indexed) {
        final w = body(q.dx, q.dy);
        i == 0 ? path.moveTo(w.dx, w.dy) : path.lineTo(w.dx, w.dy);
      }
      return path..close();
    }

    final jumper = shape(const [
      Offset(-10, 38),
      Offset(10, 38),
      Offset(13.5, 31),
      Offset(15, 8),
      Offset(15.5, -4),
      Offset(12, -7.5),
      Offset(-12, -7.5),
      Offset(-15.5, -4),
      Offset(-15, 8),
      Offset(-13.5, 31),
    ]);
    canvas
      ..drawPath(jumper, _fill(_jumper))
      ..drawPath(jumper, _line(_jumper, 4))
      // Shade on the side away from the light.
      ..drawPath(
        shape(const [
          Offset(-10, 38),
          Offset(-4, 38),
          Offset(-6.5, -7.5),
          Offset(-12, -7.5),
          Offset(-15.5, -4),
          Offset(-15, 8),
          Offset(-13.5, 31),
        ]),
        _fill(_jumperShade, 0.25 + 0.35 * shift),
      )
      // Ribbed hem and a soft collar.
      ..drawLine(body(-14, -5), body(14, -5), _line(_jumperShade, 3.4))
      ..drawLine(body(-5, 37.5), body(5, 37.5), _line(_jumperLight, 3.6));

    // A blanket hides her arms; otherwise the near arm goes on last.
    final blanket = s[_P.blanket];
    var nearHand =
        nearShoulder +
        _dir(s[_P.armNU]) * upperArm +
        _dir(s[_P.armNF]) * foreArm;
    if (blanket > 0.5) {
      nearHand = arm(nearShoulder, s[_P.armNU], s[_P.armNF], near: true);
      _blanket(canvas, hip, shoulder, knee, blanket);
    }

    // Neck, head, hair.
    final skin = Color.lerp(_skin, const Color(0xFFD5604C), 0.55 * s[_P.hot])!;
    Offset onHead(double x, double y) => head + _rot(Offset(x, y), headAngle);
    canvas
      ..drawLine(shoulder - up * 1, head, _line(_skinShade, 5.5))
      ..drawCircle(onHead(-1.8 * shift, -1.3), headR + 1.6, _fill(_hair))
      ..drawCircle(head, headR, _fill(skin))
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: head, radius: headR)))
      ..drawCircle(onHead(-3 * shift, -12.5), 8, _fill(_hair))
      ..restore();
    final mouth = _face(canvas, head, headAngle);

    // What she's holding, then the arm in front.
    if (blanket <= 0.5) {
      final book = s[_P.book];
      if (book > 0.01) {
        _book(canvas, Offset.lerp(nearHand, farHand, 0.5)!, book);
      }
      nearHand = arm(nearShoulder, s[_P.armNU], s[_P.armNF], near: true);
      final phone = s[_P.phone];
      if (phone > 0.01) {
        canvas
          ..save()
          ..translate(nearHand.dx, nearHand.dy)
          ..rotate(-s[_P.armNF])
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTRB(-4.5, -3, 4.5, 12),
              const Radius.circular(2.5),
            ),
            _fill(_ink, phone),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTRB(-3, -1, 3, 9.5),
              const Radius.circular(1.5),
            ),
            _fill(const Color(0xFF9AD8FF), phone),
          )
          ..restore();
      }
      final writing = s[_P.writing];
      if (writing > 0.01) {
        canvas.drawLine(
          nearHand + const Offset(-1, 1),
          nearHand + const Offset(6, -9),
          _line(const Color(0xFFF29A38).withValues(alpha: writing), 2.4),
        );
      }
    }
    return (head: head, hand: nearHand, mouth: mouth);
  }

  void _blanket(
    Canvas canvas,
    Offset hip,
    Offset shoulder,
    Offset knee,
    double a,
  ) {
    const teal = Color(0xFF7CC4B8);
    final stripe = _line(const Color(0xFFBFE6DF).withValues(alpha: a), 3);
    if (s[_P.tucked] > 0.5) {
      // Lying down: tucked in from her chest to her toes.
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(hip.dx - 26, hip.dy - 10, 154, hip.dy + 8),
            const Radius.circular(9),
          ),
          _fill(teal, a),
        )
        ..drawLine(
          Offset(hip.dx - 18, hip.dy - 5),
          Offset(146, hip.dy - 5),
          stripe,
        );
      return;
    }
    // Sitting: wrapped round her shoulders and over her lap.
    final wrap = Path()
      ..moveTo(shoulder.dx - 11, shoulder.dy - 1)
      ..quadraticBezierTo(
        shoulder.dx,
        shoulder.dy - 9,
        shoulder.dx + 11,
        shoulder.dy + 1,
      )
      ..lineTo(knee.dx + 6, knee.dy - 4)
      ..lineTo(knee.dx + 4, knee.dy + 10)
      ..lineTo(hip.dx - 11, hip.dy + 8)
      ..close();
    canvas
      ..drawPath(wrap, _fill(teal, a))
      ..drawPath(wrap, _line(teal.withValues(alpha: a), 3))
      ..drawLine(
        Offset.lerp(shoulder, hip, 0.45)! + const Offset(-8, 0),
        Offset.lerp(shoulder, knee, 0.55)! + const Offset(4, 0),
        stripe,
      );
  }

  void _book(Canvas canvas, Offset c, double a) {
    Path page(double side) => Path()
      ..moveTo(c.dx, c.dy - 3)
      ..lineTo(c.dx + side * 10, c.dy - 7)
      ..lineTo(c.dx + side * 10, c.dy + 2)
      ..lineTo(c.dx, c.dy + 6)
      ..close();
    for (final side in [-1.0, 1.0]) {
      canvas
        ..drawPath(page(side), _fill(AppColors.white, a))
        ..drawPath(
          page(side),
          _line(AppColors.lavender.withValues(alpha: a), 1.6),
        );
    }
  }

  /// Draws her face; returns where her mouth is.
  Offset _face(Canvas canvas, Offset head, double headAngle) {
    Offset at(double x, double y) => head + _rot(Offset(x, y), headAngle);
    const eyeInk = Color(0xFF241614);
    final shift = s[_P.faceShift];
    final x1 = -3.2 + 4.4 * shift, x2 = 3.2 + 2.6 * shift;
    // Rosy cheeks.
    for (final x in [x1 - 1.4, x2 + 1.2]) {
      canvas.drawOval(
        Rect.fromCenter(center: at(x, 3.4), width: 3.8, height: 2.3),
        _fill(const Color(0xFFF07C8C), 0.5),
      );
    }
    if (s[_P.eyes] < 0.5) {
      // Closed: soft curved lids.
      for (final x in [x1, x2]) {
        final a = at(x - 1.9, -0.8), b = at(x + 1.9, -0.8);
        final c = at(x, 1);
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, a.dy)
            ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy),
          _line(eyeInk, 1.4),
        );
      }
    } else {
      final wide = 1 + 0.35 * s[_P.eyesWide];
      for (final x in [x1, x2]) {
        canvas
          ..drawOval(
            Rect.fromCenter(
              center: at(x, -0.8),
              width: 2.5 * wide,
              height: 3.3 * wide,
            ),
            _fill(eyeInk),
          )
          ..drawCircle(at(x + 0.5, -1.6), 0.6, _fill(AppColors.white));
      }
    }
    // Brows: soft, or drawn in hard when she's cross.
    final brow = s[_P.brow].clamp(0.0, 1.0);
    final browPaint = _line(eyeInk.withValues(alpha: 0.75 + 0.25 * brow), 1.3);
    canvas
      ..drawLine(
        at(x1 - 2, -4.6 - 1.4 * brow),
        at(x1 + 1.8, -4.9 + 1.2 * brow),
        browPaint,
      )
      ..drawLine(
        at(x2 + 2, -4.6 - 1.4 * brow),
        at(x2 - 1.8, -4.9 + 1.2 * brow),
        browPaint,
      );
    // A little nose, side-on.
    if (shift > 0.4) {
      canvas.drawCircle(
        at(x2 + 3.2, 1.6),
        1.1,
        _fill(_skinShade, (shift - 0.4) / 0.6),
      );
    }
    const lips = Color(0xFF6B2A2A);
    final mx = 2.8 * shift;
    final open = s[_P.mouthOpen];
    if (open > 0.12) {
      // A yawn, or talking.
      canvas.drawOval(
        Rect.fromCenter(
          center: at(mx, 5),
          width: 2.8 + 2.2 * open,
          height: 1.8 + 4.2 * open,
        ),
        _fill(lips),
      );
    } else {
      final m0 = at(mx - 3, 4.6), m1 = at(mx + 3, 4.6);
      final mc = at(mx, 4.6 + 3.8 * s[_P.smile]);
      canvas.drawPath(
        Path()
          ..moveTo(m0.dx, m0.dy)
          ..quadraticBezierTo(mc.dx, mc.dy, m1.dx, m1.dy),
        _line(lips, 1.5),
      );
    }
    final thermo = s[_P.thermo];
    if (thermo > 0.01) {
      final from = at(mx + 2, 5), tip = at(mx + 12, 7.5);
      canvas
        ..drawLine(
          from,
          tip,
          _line(AppColors.white.withValues(alpha: thermo), 3.2),
        )
        ..drawLine(from, tip, _line(_ink.withValues(alpha: 0.35 * thermo), 1))
        ..drawCircle(tip, 2, _fill(_red, thermo));
    }
    return at(mx + 4, 4.6);
  }

  // -------------------------------------------------------------------------
  // Thoughts and words
  // -------------------------------------------------------------------------

  Offset _bubbleAt(Offset head) => Offset(
    (head.dx + 62).clamp(60.0, 200.0),
    (head.dy - 22).clamp(27.0, 140.0),
  );

  void _trailTo(Canvas canvas, Offset head, Offset target, double a) {
    if (a <= 0.01) return;
    final from = head + const Offset(14, -10);
    for (final (i, t) in const [0.12, 0.48, 0.86].indexed) {
      final c = Offset.lerp(from, target, t)!;
      final r = (2.2 + i) * a;
      canvas
        ..drawCircle(c, r, _fill(AppColors.white))
        ..drawCircle(c, r, _thin);
    }
  }

  void _thoughts(Canvas canvas, Offset head) {
    final at = _bubbleAt(head);
    final bubble = s[_P.bubble];
    final showsItems = s[_P.item0] + s[_P.item1] + s[_P.item2] > 0.02;
    _trailTo(
      canvas,
      head,
      showsItems
          ? _itemAt[0] + const Offset(-16, 10)
          : at + const Offset(-30, 12),
      s[_P.trail] * (1 - s[_P.feelings]).clamp(0.0, 1.0),
    );
    if (bubble > 0.01) {
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 66 * bubble, height: 38 * bubble),
        const Radius.circular(19),
      );
      canvas
        ..drawRRect(box, _fill(AppColors.white))
        ..drawRRect(box, _thin);
      final dots = s[_P.bubbleDots] * bubble;
      if (dots > 0.01) {
        for (var i = 0; i < 3; i++) {
          final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (sec - i * 0.25));
          canvas.drawCircle(
            at + Offset(-14.0 + i * 14, 0),
            (2.4 + 1.8 * pulse) * dots,
            _fill(AppColors.lavender, 0.5 + 0.5 * pulse),
          );
        }
      }
      final friend = s[_P.friend] * bubble;
      if (friend > 0.01) {
        // Someone she hasn't spoken to in a while.
        final c = at + Offset(0, 1 - 1.5 * math.sin(math.pi * sec / 2));
        final ink = _ink.withValues(alpha: friend.clamp(0.0, 1.0));
        canvas
          ..drawCircle(c, 9 * friend, _fill(const Color(0xFFFFF3D9)))
          ..drawCircle(c, 9 * friend, _line(ink, 2.4))
          ..drawCircle(c + const Offset(-3, -2), 1.3, _fill(_ink, friend))
          ..drawCircle(c + const Offset(3, -2), 1.3, _fill(_ink, friend))
          ..drawPath(
            Path()
              ..moveTo(c.dx - 3.5, c.dy + 2.5)
              ..quadraticBezierTo(c.dx, c.dy + 6.5, c.dx + 3.5, c.dy + 2.5),
            _line(ink, 1.6),
          );
      }
      final heart = s[_P.bubbleHeart] * bubble;
      if (heart > 0.01) {
        canvas
          ..save()
          ..translate(at.dx, at.dy)
          ..scale(1.2 * heart * (1 + 0.12 * math.sin(2 * math.pi * sec)));
        _heart(canvas);
        canvas.restore();
      }
    }
    final sizes = [s[_P.item0], s[_P.item1], s[_P.item2]];
    for (var k = 0; k < 3; k++) {
      if (sizes[k] <= 0.01) continue;
      canvas
        ..save()
        ..translate(_itemAt[k].dx, _itemAt[k].dy)
        ..scale(sizes[k])
        ..drawCircle(Offset.zero, 14, _fill(AppColors.white))
        ..drawCircle(Offset.zero, 14, _thin);
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
    final question = s[_P.question];
    if (question > 0.01) {
      final p = head + Offset(-3, -30 - 3 * s[_P.questionBob]);
      final color = AppColors.lavender.withValues(
        alpha: question.clamp(0.0, 1.0),
      );
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
          _line(color, 2.8),
        )
        ..drawCircle(p + const Offset(0, 8), 1.8, Paint()..color = color);
    }
  }

  /// A feeling as a little shape: 0 angry, 1 anxious, 2 sad.
  void _feelShape(Canvas canvas, int i, Offset c, double size, double a) {
    if (a <= 0.01) return;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(size);
    switch (i) {
      case 0:
        final star = Path();
        for (var k = 0; k < 20; k++) {
          final r = k.isEven ? 8.5 : 5.0;
          final ang = k * math.pi / 10 - math.pi / 2;
          final p = Offset(math.cos(ang), math.sin(ang)) * r;
          k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(star..close(), _fill(_red, a));
      case 1:
        final p = _line(
          const Color(0xFF34B27D).withValues(alpha: a.clamp(0.0, 1.0)),
          2.2,
        );
        for (final y in [-5.0, 0.0, 5.0]) {
          final w = Path()..moveTo(-8, y);
          for (var k = 0; k < 4; k++) {
            w.quadraticBezierTo(
              -6.0 + k * 4,
              y + (k.isEven ? -2.5 : 2.5),
              -4.0 + k * 4,
              y,
            );
          }
          canvas.drawPath(w, p);
        }
      default:
        canvas.drawPath(
          Path()
            ..moveTo(-6, 3)
            ..cubicTo(-10, -4, -3, -9, 1, -6)
            ..cubicTo(4, -4, 3, -1, 6, 0)
            ..cubicTo(11, 3, 8, 9, 2, 8)
            ..cubicTo(-2, 8, -4, 7, -6, 3)
            ..close(),
          _fill(const Color(0xFF8E5BD6), a),
        );
    }
    canvas.restore();
  }

  void _feelings(Canvas canvas, Offset head) {
    final a = s[_P.feelings];
    if (a <= 0.01) return;
    final at = Offset(
      (head.dx + 60).clamp(60.0, 190.0),
      (head.dy - 22).clamp(27.0, 140.0),
    );
    _trailTo(canvas, head, at + const Offset(-42, 12), a);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: 92 * a, height: 40 * a),
      const Radius.circular(20),
    );
    canvas
      ..drawRRect(box, _fill(AppColors.white))
      ..drawRRect(box, _thin);
    final picked = s[_P.feelingAt].round();
    for (var i = 0; i < 3; i++) {
      final lit = i == picked;
      _feelShape(
        canvas,
        i,
        at + Offset(-28.0 + i * 28, 0),
        lit ? 1.15 : 0.8,
        a * (lit ? 1 : 0.4),
      );
    }
  }

  void _speech(Canvas canvas, Offset head) {
    final a = s[_P.speech];
    if (a > 0.01) {
      // What she says out loud.
      final at = head + const Offset(46, -22);
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 44 * a, height: 30 * a),
        const Radius.circular(12),
      );
      canvas
        ..drawPath(
          Path()
            ..moveTo(at.dx - 16, at.dy + 12)
            ..lineTo(at.dx - 26, at.dy + 22)
            ..lineTo(at.dx - 6, at.dy + 14)
            ..close(),
          _fill(AppColors.white, a),
        )
        ..drawRRect(box, _fill(AppColors.white))
        ..drawRRect(box, _thin);
      _feelShape(canvas, 2, at, 1.1 * a, a);
    }
    final incoming = s[_P.incoming];
    if (incoming > 0.01) {
      // Their reply.
      final at = Offset(
        196 + 14 * (1 - incoming),
        66 + 2.5 * math.sin(math.pi * sec / 2),
      );
      final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: at, width: 36, height: 26),
        const Radius.circular(11),
      );
      final white = _fill(AppColors.white, incoming);
      canvas
        ..drawPath(
          Path()
            ..moveTo(at.dx + 8, at.dy + 10)
            ..lineTo(at.dx + 16, at.dy + 20)
            ..lineTo(at.dx - 2, at.dy + 12)
            ..close(),
          white,
        )
        ..drawRRect(box, white)
        ..drawRRect(box, _thin)
        ..save()
        ..translate(at.dx, at.dy)
        ..scale(0.95 + 0.1 * math.sin(2 * math.pi * sec));
      _heart(canvas, incoming);
      canvas.restore();
    }
  }

  /// Sleep, steam, worry, a pause: what shows over her head.
  void _aboveHead(Canvas canvas, Offset head) {
    final zzz = s[_P.zzz];
    if (zzz > 0.01) {
      for (var i = 0; i < 3; i++) {
        final p = (sec / 2 + i / 3) % 1.0;
        final c = head + Offset(16 + 12 * p, -12 - 30 * p);
        final size = 3.0 + 4 * p;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - size, c.dy - size)
            ..lineTo(c.dx + size, c.dy - size)
            ..lineTo(c.dx - size, c.dy + size)
            ..lineTo(c.dx + size, c.dy + size),
          _line(_ink.withValues(alpha: 0.55 * zzz * math.sin(math.pi * p)), 2),
        );
      }
    }
    final steam = s[_P.steam];
    if (steam > 0.01) {
      for (var i = 0; i < 4; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final p = (sec + i * 0.25) % 1.0;
        final c = head + Offset(side * (12 + 7 * p), -10 - 16 * p);
        final a = steam * (1 - p);
        canvas
          ..drawCircle(c, 2.5 + 4 * p, _fill(AppColors.white, a))
          ..drawCircle(
            c,
            2.5 + 4 * p,
            _line(_ink.withValues(alpha: (0.4 * a).clamp(0.0, 1.0)), 1.4),
          );
      }
    }
    final scribble = s[_P.scribble];
    if (scribble > 0.01) {
      // A tangle of worry, turning.
      final c = head + const Offset(0, -25);
      final path = Path();
      for (var k = 0; k <= 60; k++) {
        final ang = k * 0.42 + sec * math.pi / 2;
        final r = 6 + 5 * math.sin(k * 1.3);
        final p = c + Offset(math.cos(ang) * r * 1.3, math.sin(ang) * r * 0.8);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        _line(_ink.withValues(alpha: 0.55 * scribble), 1.6),
      );
    }
    final sweat = s[_P.sweat];
    if (sweat > 0.01) {
      for (var i = 0; i < 2; i++) {
        final side = i == 0 ? -1.0 : 1.0;
        final p = (sec * 2 + i * 0.5) % 1.0;
        canvas.drawCircle(
          head + Offset(side * (13 + 8 * p), -7 + 9 * p),
          2.2,
          _fill(_blue, sweat * (1 - p)),
        );
      }
    }
    final pause = s[_P.pause];
    if (pause > 0.01) {
      final c = head + const Offset(0, -28);
      final r = 11 * (0.9 + 0.1 * math.sin(math.pi * sec)) * pause;
      canvas
        ..drawCircle(c, r, _fill(AppColors.white, pause))
        ..drawCircle(c, r, _line(_ink.withValues(alpha: 0.3 * pause), 1.5));
      for (final x in [-3.2, 3.2]) {
        canvas.drawLine(
          c + Offset(x, -4.5),
          c + Offset(x, 4.5),
          _line(_ink.withValues(alpha: pause.clamp(0.0, 1.0)), 3),
        );
      }
    }
  }

  /// What comes from the phone in her hand.
  void _fromHand(Canvas canvas, Offset hand) {
    final messages = s[_P.messages];
    if (messages > 0.01) {
      for (var i = 0; i < 3; i++) {
        final p = (sec / 2 + i / 3) % 1.0;
        final c = hand + Offset(12 + 44 * p, -10 - 48 * p);
        final a = (messages * math.sin(math.pi * p)).clamp(0.0, 1.0);
        final box = RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 20 + 6 * p, height: 14 + 4 * p),
          const Radius.circular(7),
        );
        canvas
          ..drawRRect(box, _fill(AppColors.white, a))
          ..drawRRect(box, _line(AppColors.lavender.withValues(alpha: a), 1.5));
        if (i == 0) {
          canvas
            ..save()
            ..translate(c.dx, c.dy)
            ..scale(0.6);
          _heart(canvas, a);
          canvas.restore();
        } else {
          for (final x in [-4.0, 0.0, 4.0]) {
            canvas.drawCircle(
              c + Offset(x, 0),
              1.3,
              _fill(AppColors.lavender, a),
            );
          }
        }
      }
    }
    final sound = s[_P.sound];
    if (sound > 0.01) {
      for (var i = 0; i < 3; i++) {
        final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * (sec - i * 0.2));
        canvas.drawArc(
          Rect.fromCircle(
            center: hand + const Offset(6, -4),
            radius: 8.0 + i * 5,
          ),
          -math.pi / 4,
          math.pi / 2,
          false,
          _line(
            AppColors.lavender.withValues(
              alpha: (sound * pulse).clamp(0.0, 1.0),
            ),
            2,
          ),
        );
      }
    }
  }

  /// Long, slow breaths out.
  void _breathOut(Canvas canvas, Offset mouth) {
    final puff = s[_P.puff];
    if (puff <= 0.01) return;
    for (var i = 0; i < 3; i++) {
      final p = (sec / 2 + i / 3) % 1.0;
      canvas.drawCircle(
        mouth + Offset(8 + 30 * p, 1 - 3 * p),
        2 + 4 * p,
        _line(_blue.withValues(alpha: (puff * (1 - p)).clamp(0.0, 1.0)), 1.6),
      );
    }
  }

  /// Tomorrow's list, off her mind and onto paper.
  void _note(Canvas canvas) {
    final note = s[_P.note];
    if (note <= 0.01) return;
    final card = RRect.fromRectAndRadius(
      const Rect.fromLTRB(152, 20, 196, 70),
      const Radius.circular(8),
    );
    canvas
      ..drawRRect(card, _fill(AppColors.white, note))
      ..drawRRect(card, _thin);
    final lines = s[_P.noteLines];
    for (var i = 0; i < 3; i++) {
      final done = (lines - i).clamp(0.0, 1.0);
      if (done <= 0) continue;
      final y = 33.0 + i * 12;
      canvas
        ..drawCircle(Offset(160, y), 2, _fill(AppColors.mint, note))
        ..drawLine(
          Offset(166, y),
          Offset(166 + 24 * done, y),
          _line(_ink.withValues(alpha: 0.5 * note), 2),
        );
    }
  }

  /// Whatever set her off.
  void _trigger(Canvas canvas) {
    final trigger = s[_P.trigger];
    if (trigger <= 0.01) return;
    const c = Offset(206, 106);
    final size = (9 + 8 * trigger) * (1 + 0.08 * math.sin(2 * math.pi * sec));
    final spark = Path();
    for (var k = 0; k < 16; k++) {
      final r = k.isEven ? size : size * 0.55;
      final ang = k * math.pi / 8 + sec * math.pi / 8;
      final p = c + Offset(math.cos(ang), math.sin(ang)) * r;
      k == 0 ? spark.moveTo(p.dx, p.dy) : spark.lineTo(p.dx, p.dy);
    }
    final white = AppColors.white.withValues(alpha: trigger.clamp(0.0, 1.0));
    canvas
      ..drawPath(spark..close(), _fill(_red, trigger))
      ..drawLine(
        c + const Offset(0, -5),
        c + const Offset(0, 1),
        _line(white, 2.6),
      )
      ..drawCircle(c + const Offset(0, 5), 1.6, Paint()..color = white);
  }

  void _heart(Canvas canvas, [double alpha = 1]) {
    const r = 7.0;
    canvas.drawPath(
      Path()
        ..moveTo(0, r * 0.85)
        ..cubicTo(-r * 1.4, -r * 0.1, -r * 0.6, -r * 1.1, 0, -r * 0.3)
        ..cubicTo(r * 0.6, -r * 1.1, r * 1.4, -r * 0.1, 0, r * 0.85)
        ..close(),
      _fill(_red, alpha),
    );
  }

  void _cup(Canvas canvas) {
    const cup = Color(0xFFE9804C);
    canvas
      ..drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTRB(-6, -2, 4, 7),
          bottomLeft: const Radius.circular(4),
          bottomRight: const Radius.circular(4),
        ),
        _fill(cup),
      )
      ..drawArc(
        const Rect.fromLTRB(1, 0, 9, 6),
        -math.pi / 2,
        math.pi,
        false,
        _line(cup, 1.8),
      );
    final steam = _line(_ink.withValues(alpha: 0.3), 1.4);
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
    canvas.drawPath(star..close(), _fill(const Color(0xFFF7C23E)));
  }

  /// Days (or breaths), ticking off one by one.
  void _weekDots(Canvas canvas) {
    final week = s[_P.week];
    if (week <= 0.01) return;
    final count = s[_P.weekCount].round();
    final filled = s[_P.weekFilled];
    final start = 120 - (count - 1) * 7.5;
    for (var i = 0; i < count; i++) {
      final c = Offset(start + i * 15, 24);
      final fill = (filled - i).clamp(0.0, 1.0);
      canvas
        ..drawCircle(c, 5, _fill(AppColors.white, week))
        ..drawCircle(c, 5, _line(_ink.withValues(alpha: 0.2 * week), 1.4));
      if (fill > 0) {
        canvas.drawCircle(
          c,
          5 * Curves.easeOutBack.transform(fill),
          _fill(AppColors.mint, week),
        );
      }
    }
  }

  void _sparkles(Canvas canvas) {
    final sparkles = s[_P.sparkles];
    if (sparkles <= 0.01) return;
    const at = [
      Offset(98, 44),
      Offset(204, 36),
      Offset(88, 96),
      Offset(212, 92),
      Offset(122, 16),
      Offset(186, 126),
    ];
    for (var i = 0; i < at.length; i++) {
      final twinkle = 0.5 + 0.5 * math.sin(2 * math.pi * sec + i * 1.7);
      final size = (3 + 5 * twinkle) * sparkles;
      final c = at[i];
      canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - size)
          ..lineTo(c.dx + size * 0.28, c.dy - size * 0.28)
          ..lineTo(c.dx + size, c.dy)
          ..lineTo(c.dx + size * 0.28, c.dy + size * 0.28)
          ..lineTo(c.dx, c.dy + size)
          ..lineTo(c.dx - size * 0.28, c.dy + size * 0.28)
          ..lineTo(c.dx - size, c.dy)
          ..lineTo(c.dx - size * 0.28, c.dy - size * 0.28)
          ..close(),
        _fill(
          i.isEven ? const Color(0xFFF7C23E) : AppColors.lavender,
          sparkles,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
