// Draws the GoDoctor app icon to assets/icon/*.png.
//
// Run with:  flutter test tool/generate_icon_test.dart
// (It's a "test" only because that's the easiest way to get dart:ui image
// encoding without a device. It lives in tool/, so `flutter test` on its own
// does not run it.) Then run:  dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _primary = Color(0xFF1B63F2);
const _primaryDark = Color(0xFF0D3E8F);

/// Paints the white pulse line + cross onto [canvas], scaled to [size] and
/// shrunk by [scale] around the centre (adaptive icons need a safe zone).
void _paintMark(Canvas canvas, double size, {double scale = 1}) {
  canvas.save();
  canvas.translate(size / 2, size / 2);
  canvas.scale(scale);
  canvas.translate(-size / 2, -size / 2);

  final line = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.055
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Offset p(double x, double y) => Offset(size * x, size * y);
  final pulse = Path()
    ..moveTo(p(0.17, 0.58).dx, p(0.17, 0.58).dy)
    ..lineTo(p(0.35, 0.58).dx, p(0.35, 0.58).dy)
    ..lineTo(p(0.43, 0.42).dx, p(0.43, 0.42).dy)
    ..lineTo(p(0.53, 0.74).dx, p(0.53, 0.74).dy)
    ..lineTo(p(0.61, 0.50).dx, p(0.61, 0.50).dy)
    ..lineTo(p(0.67, 0.58).dx, p(0.67, 0.58).dy)
    ..lineTo(p(0.83, 0.58).dx, p(0.83, 0.58).dy);
  canvas.drawPath(pulse, line);

  // Medical cross above the pulse.
  final cross = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.05
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(p(0.5, 0.20), p(0.5, 0.34), cross);
  canvas.drawLine(p(0.43, 0.27), p(0.57, 0.27), cross);
  canvas.restore();
}

Future<void> _write(String path, void Function(Canvas, double) paint) async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size);
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('generate icons', (tester) async {
    await tester.runAsync(() async {
      // Full-bleed icon (legacy Android, web, iOS).
      await _write('assets/icon/icon.png', (canvas, size) {
        final rect = Rect.fromLTWH(0, 0, size, size);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_primary, _primaryDark],
            ).createShader(rect),
        );
        canvas.drawCircle(
          Offset(size * 0.92, size * 0.08),
          size * 0.32,
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
        canvas.drawCircle(
          Offset(size * 0.05, size * 0.98),
          size * 0.38,
          Paint()..color = Colors.white.withValues(alpha: 0.07),
        );
        _paintMark(canvas, size);
      });

      // Transparent foreground for Android adaptive icons: the OS masks it,
      // so keep the mark inside the ~66% safe zone.
      await _write('assets/icon/icon_foreground.png', (canvas, size) {
        _paintMark(canvas, size, scale: 0.62);
      });
    });
  });
}
