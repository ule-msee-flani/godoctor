import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// A part of the body (or a kind of problem) the patient can point to.
class BodyArea {
  const BodyArea(this.id, this.label, this.specialty, this.rect);

  final String id;
  final String label;

  /// The specialty that usually helps with it.
  final String specialty;

  /// Where it sits on the figure, as fractions of its box (null for the
  /// chips under the figure).
  final Rect? rect;
}

/// The front-facing figure, top to bottom, plus problems that aren't one
/// spot (chips). Pure data, so the suggestions can be tested.
const kBodyAreas = <BodyArea>[
  BodyArea('head', 'Head', 'General Practice', Rect.fromLTWH(0.40, 0.00, 0.20, 0.15)),
  BodyArea('throat', 'Ear, nose or throat', 'ENT', Rect.fromLTWH(0.44, 0.15, 0.12, 0.05)),
  BodyArea('chest', 'Chest', 'General Practice', Rect.fromLTWH(0.33, 0.20, 0.34, 0.15)),
  BodyArea('stomach', 'Stomach', 'General Practice', Rect.fromLTWH(0.35, 0.35, 0.30, 0.13)),
  BodyArea('pelvis', 'Lower belly', 'Obstetrics & Gynaecology', Rect.fromLTWH(0.37, 0.48, 0.26, 0.08)),
  BodyArea('arm_r', 'Arm', 'Orthopedics', Rect.fromLTWH(0.20, 0.21, 0.12, 0.30)),
  BodyArea('arm_l', 'Arm', 'Orthopedics', Rect.fromLTWH(0.68, 0.21, 0.12, 0.30)),
  BodyArea('leg_r', 'Leg or knee', 'Orthopedics', Rect.fromLTWH(0.37, 0.57, 0.12, 0.42)),
  BodyArea('leg_l', 'Leg or knee', 'Orthopedics', Rect.fromLTWH(0.51, 0.57, 0.12, 0.42)),
  BodyArea('back', 'Back', 'Orthopedics', null),
  BodyArea('skin', 'Skin', 'Dermatology', null),
  BodyArea('mind', 'Mood or sleep', 'Psychiatry/Mental Health', null),
  BodyArea('fever', 'Fever or whole body', 'General Practice', null),
];

/// The specialty for what was picked last (null when nothing is).
String? specialtyForAreas(List<String> pickedInOrder) {
  if (pickedInOrder.isEmpty) return null;
  return kBodyAreas.firstWhere((a) => a.id == pickedInOrder.last).specialty;
}

/// "Stomach, Back" — each label once, in the order picked.
String describeAreas(List<String> pickedInOrder) => {
  for (final id in pickedInOrder) kBodyAreas.firstWhere((a) => a.id == id).label,
}.join(', ');

/// "Where does it hurt?": tap the figure (or a chip) to show the doctor.
class BodyMap extends StatelessWidget {
  const BodyMap({super.key, required this.picked, required this.onChanged});

  /// Area ids, in the order they were tapped.
  final List<String> picked;
  final ValueChanged<List<String>> onChanged;

  void _toggle(String id) {
    HapticFeedback.selectionClick();
    final next = [...picked];
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
    onChanged(next);
  }

  bool _isOn(BodyArea a) => picked.any(
    (id) => kBodyAreas.firstWhere((b) => b.id == id).label == a.label,
  );

  @override
  Widget build(BuildContext context) {
    final figure = [
      for (final a in kBodyAreas)
        if (a.rect != null) a,
    ];
    final chips = [
      for (final a in kBodyAreas)
        if (a.rect == null) a,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox(
            width: 190,
            height: 300,
            child: LayoutBuilder(
              builder: (context, c) {
                final size = Size(c.maxWidth, c.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    for (final a in figure) {
                      final r = _scale(a.rect!, size).inflate(4);
                      if (r.contains(d.localPosition)) {
                        _toggle(a.id);
                        return;
                      }
                    }
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _FigurePainter(
                      areas: figure,
                      on: {
                        for (final a in figure)
                          if (_isOn(a)) a.id,
                      },
                    ),
                  ),
                );
              },
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
                selected: _isOn(a),
                onSelected: (_) => _toggle(a.id),
              ),
          ],
        ),
      ],
    );
  }
}

Rect _scale(Rect f, Size s) =>
    Rect.fromLTWH(f.left * s.width, f.top * s.height, f.width * s.width, f.height * s.height);

class _FigurePainter extends CustomPainter {
  _FigurePainter({required this.areas, required this.on});

  final List<BodyArea> areas;
  final Set<String> on;

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in areas) {
      final r = _scale(a.rect!, size);
      final picked = on.contains(a.id);
      final fill = Paint()
        ..color = picked ? AppColors.danger.withValues(alpha: 0.85) : AppColors.primarySoft;
      final line = Paint()
        ..color = picked ? AppColors.danger : AppColors.borderStrong
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      if (a.id == 'head') {
        canvas
          ..drawOval(r, fill)
          ..drawOval(r, line);
        continue;
      }
      final radius = Radius.circular(
        switch (a.id) {
          'throat' => 6,
          'chest' || 'stomach' || 'pelvis' => 18,
          _ => r.width / 2,
        },
      );
      final rr = RRect.fromRectAndRadius(r, radius);
      canvas
        ..drawRRect(rr, fill)
        ..drawRRect(rr, line);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) => old.on != on;
}
