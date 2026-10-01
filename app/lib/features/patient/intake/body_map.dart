import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import '../../../core/theme/app_colors.dart';
import 'body_shapes.dart';

/// A part of the body (or a kind of problem) the patient can point to.
class BodyArea {
  const BodyArea(this.id, this.label, this.specialty, {this.chip = false});

  final String id;
  final String label;

  /// The specialty that usually helps with it.
  final String specialty;

  /// Offered as a chip under the body (as well as, or instead of, on it).
  final bool chip;
}

/// Everything that can be picked: places on the body, then problems that
/// aren't one spot. Pure data, so the suggestions can be tested.
const kBodyAreas = <BodyArea>[
  BodyArea('head', 'Head', 'General Practice'),
  BodyArea('throat', 'Ear, nose or throat', 'ENT'),
  BodyArea('chest', 'Chest', 'General Practice'),
  BodyArea('stomach', 'Stomach', 'General Practice'),
  BodyArea('pelvis', 'Lower belly', 'Obstetrics & Gynaecology'),
  BodyArea('arm_r', 'Arm', 'Orthopedics'),
  BodyArea('arm_l', 'Arm', 'Orthopedics'),
  BodyArea('leg_r', 'Leg or knee', 'Orthopedics'),
  BodyArea('leg_l', 'Leg or knee', 'Orthopedics'),
  BodyArea('back', 'Back', 'Orthopedics', chip: true),
  BodyArea('skin', 'Skin', 'Dermatology', chip: true),
  BodyArea('mind', 'Mood or sleep', 'Psychiatry/Mental Health', chip: true),
  BodyArea('fever', 'Fever or whole body', 'General Practice', chip: true),
];

/// The specialty for what was picked last (null when nothing is).
String? specialtyForAreas(List<String> pickedInOrder) {
  if (pickedInOrder.isEmpty) return null;
  return kBodyAreas.firstWhere((a) => a.id == pickedInOrder.last).specialty;
}

/// "Stomach, Back" — each label once, in the order picked.
String describeAreas(List<String> pickedInOrder) => {
  for (final id in pickedInOrder)
    kBodyAreas.firstWhere((a) => a.id == id).label,
}.join(', ');

/// Which area a shape of the drawn body belongs to (null: not pickable).
String? areaForShape(BodyShape shape, {required bool back}) {
  final side = shape.side == 'left' ? '_l' : '_r';
  switch (shape.slug) {
    case 'head' || 'hair':
      return 'head';
    case 'neck':
      return back ? 'back' : 'throat';
    case 'trapezius':
      return back ? 'back' : 'throat';
    case 'chest':
      return 'chest';
    case 'abs' || 'obliques':
      return 'stomach';
    case 'upper-back' || 'lower-back' || 'gluteal':
      return 'back';
    case 'deltoids' || 'biceps' || 'triceps' || 'forearm' || 'hands':
      return 'arm$side';
    case 'adductors' ||
        'quadriceps' ||
        'knees' ||
        'tibialis' ||
        'calves' ||
        'ankles' ||
        'feet' ||
        'hamstring':
      return 'leg$side';
  }
  return null;
}

/// One body view, parsed and ready to draw and tap.
class _Parsed {
  _Parsed(this.view, {required bool back})
    : outline = parseSvgPathData(view.outline),
      shapes = [for (final s in view.shapes) parseSvgPathData(s.d)] {
    areas = [for (final s in view.shapes) areaForShape(s, back: back)];
    // The lowest pair of tummy shapes is the lower belly.
    final tummy = [
      for (var i = 0; i < areas.length; i++)
        if (view.shapes[i].slug == 'abs') i,
    ];
    if (!back && tummy.isNotEmpty) {
      final lowest = tummy
          .map((i) => shapes[i].getBounds().center.dy)
          .reduce(math.max);
      for (final i in tummy) {
        if (shapes[i].getBounds().center.dy > lowest - 30) areas[i] = 'pelvis';
      }
    }
  }

  final BodyView view;
  final Path outline;
  final List<Path> shapes;
  late final List<String?> areas;

  static final _cache = <BodyView, _Parsed>{};

  static _Parsed of(BodyView view, {required bool back}) =>
      _cache.putIfAbsent(view, () => _Parsed(view, back: back));

  /// The area at [p] (in the body's own coordinates). A tap that lands in a
  /// gap between shapes goes to the nearest one.
  String? areaAt(Offset p) {
    for (var i = shapes.length - 1; i >= 0; i--) {
      if (areas[i] != null && shapes[i].contains(p)) return areas[i];
    }
    String? best;
    var bestDistance = 26.0;
    for (var i = 0; i < shapes.length; i++) {
      if (areas[i] == null) continue;
      final b = shapes[i].getBounds();
      final dx = math.max(0, math.max(b.left - p.dx, p.dx - b.right));
      final dy = math.max(0, math.max(b.top - p.dy, p.dy - b.bottom));
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < bestDistance) {
        bestDistance = d.toDouble();
        best = areas[i];
      }
    }
    return best;
  }
}

/// "Where does it hurt?": a realistic body, front and back, to tap on (or
/// chips for problems that aren't one spot), to show the doctor.
class BodyMap extends StatefulWidget {
  const BodyMap({
    super.key,
    required this.picked,
    required this.onChanged,
    this.female = false,
  });

  /// Area ids, in the order they were tapped.
  final List<String> picked;
  final ValueChanged<List<String>> onChanged;

  /// Show a woman's body (otherwise a man's).
  final bool female;

  @override
  State<BodyMap> createState() => _BodyMapState();
}

class _BodyMapState extends State<BodyMap> with SingleTickerProviderStateMixin {
  bool _back = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  BodyView get _view => widget.female
      ? (_back ? femaleBack : femaleFront)
      : (_back ? maleBack : maleFront);

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    final next = [...widget.picked];
    // Both arms (or legs) count as one.
    final same = kBodyAreas.firstWhere((a) => a.id == id).label;
    final twins = [
      for (final a in kBodyAreas)
        if (a.label == same) a.id,
    ];
    if (next.any(twins.contains)) {
      next.removeWhere(twins.contains);
    } else {
      next.add(id);
    }
    widget.onChanged(next);
  }

  /// Picked areas, with both arms (or legs) lit when either is picked.
  Set<String> get _lit => {
    for (final a in kBodyAreas)
      if (widget.picked.any(
        (id) => kBodyAreas.firstWhere((b) => b.id == id).label == a.label,
      ))
        a.id,
  };

  @override
  Widget build(BuildContext context) {
    final lit = _lit;
    final chips = [
      for (final a in kBodyAreas)
        if (a.chip) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Front')),
              ButtonSegment(value: true, label: Text('Back')),
            ],
            selected: {_back},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              HapticFeedback.selectionClick();
              setState(() => _back = s.first);
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 360,
          // Turning round: the body swings away and the other side swings
          // in, like a model on a turntable.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 460),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, a) => AnimatedBuilder(
              animation: a,
              builder: (context, child) => Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateY((1 - a.value) * math.pi / 2),
                child: child,
              ),
              child: child,
            ),
            child: _Figure(
              key: ValueKey(_view),
              view: _view,
              back: _back,
              lit: lit,
              pulse: _pulse,
              onTap: _toggle,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in chips)
              FilterChip(
                label: Text(a.label),
                selected: lit.contains(a.id),
                onSelected: (_) => _toggle(a.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    super.key,
    required this.view,
    required this.back,
    required this.lit,
    required this.pulse,
    required this.onTap,
  });

  final BodyView view;
  final bool back;
  final Set<String> lit;
  final Animation<double> pulse;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final parsed = _Parsed.of(view, back: back);
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final fit = _Fit(view.viewBox, size);
        return Semantics(
          label: back
              ? 'The back of the body. Tap where it hurts.'
              : 'The front of the body. Tap where it hurts.',
          child: GestureDetector(
            key: const ValueKey('body-figure'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final area = parsed.areaAt(fit.toBody(d.localPosition));
              if (area != null) onTap(area);
            },
            child: RepaintBoundary(
              child: CustomPaint(
                size: size,
                painter: _BodyPainter(parsed, fit, lit, pulse),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fits the body's drawing area into the widget, centred.
class _Fit {
  _Fit(this.box, Size size)
    : scale = math.min(size.width / box.width, size.height / box.height) {
    offset = Offset(
      (size.width - box.width * scale) / 2,
      (size.height - box.height * scale) / 2,
    );
  }

  final Rect box;
  final double scale;
  late final Offset offset;

  Offset toBody(Offset local) => (local - offset) / scale + box.topLeft;
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.parsed, this.fit, this.lit, this.pulse)
    : super(repaint: pulse);

  final _Parsed parsed;
  final _Fit fit;
  final Set<String> lit;
  final Animation<double> pulse;

  // Warm skin, in two tones so the muscles read; dark hair.
  static const _skinLight = Color(0xFFDDA27B);
  static const _skin = Color(0xFFC4825C);
  static const _skinDeep = Color(0xFFA9694A);
  static const _hair = Color(0xFF2A1A14);
  static const _pain = Color(0xFFE5484D);

  @override
  void paint(Canvas canvas, Size size) {
    final box = parsed.view.viewBox;
    canvas
      ..save()
      ..translate(fit.offset.dx, fit.offset.dy)
      ..scale(fit.scale)
      ..translate(-box.left, -box.top);

    // A soft shadow under the feet.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(box.center.dx, box.bottom - box.height * 0.012),
        width: box.width * 0.42,
        height: box.height * 0.022,
      ),
      Paint()..color = AppColors.ink.withValues(alpha: 0.08),
    );

    // The body: the outline filled, lit from the top left.
    final light = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 1.1,
        colors: const [_skinLight, _skin],
      ).createShader(box);
    canvas
      ..drawPath(parsed.outline, light)
      ..drawPath(
        parsed.outline,
        Paint()
          ..color = _skinDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 / fit.scale * 1.4,
      );

    // Muscles and features, a shade deeper, so the shape of a real body
    // shows; picked areas glow.
    final glow = 0.55 + 0.45 * pulse.value;
    final muscle = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 1.1,
        colors: const [_skin, _skinDeep],
      ).createShader(box);
    for (var i = 0; i < parsed.shapes.length; i++) {
      final shape = parsed.view.shapes[i];
      final path = parsed.shapes[i];
      final area = parsed.areas[i];
      if (shape.slug == 'hair') {
        canvas.drawPath(path, Paint()..color = _hair);
        continue;
      }
      if (area != null && lit.contains(area)) {
        canvas
          ..drawPath(
            path,
            Paint()
              ..color = _pain.withValues(alpha: 0.35 * glow)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 14
              ..strokeJoin = StrokeJoin.round,
          )
          ..drawPath(path, Paint()..color = Color.lerp(_pain, _skin, 0.12)!);
        continue;
      }
      canvas.drawPath(path, muscle);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.parsed != parsed || old.lit.length != lit.length || old.fit != fit;
}
