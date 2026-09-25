// Builds Android's adaptive-icon foreground from the app icon you supplied.
//
//   flutter test tool/generate_icon_test.dart
//   dart run flutter_launcher_icons
//
// Reads  assets/logo/app_icon.png            (your full square icon)
// Writes assets/logo/app_icon_foreground.png (transparent, artwork centred and
//                                            shrunk to sit inside the safe zone
//                                            Android never crops)
// and prints the background colour to use as `adaptive_icon_background` in
// pubspec.yaml.
//
// It's a "test" only because that's the easiest way to get dart:ui image
// decoding/encoding without a device. Assumes LIGHT artwork on a roughly
// plain DARK background (as the current logo is); the artwork is cut out by
// how much brighter than the background each pixel is.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _canvas = 1024;

/// Longest side of the artwork, as a share of the canvas. Android shows a
/// ~66% window (and OEM shapes can round the corners), so stay well inside.
const _artworkShare = 0.52;

void main() {
  testWidgets('build adaptive icon foreground', (tester) async {
    await tester.runAsync(() async {
      final source = File('assets/logo/app_icon.png').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(source);
      final image = (await codec.getNextFrame()).image;
      final w = image.width, h = image.height;
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();

      // Background colour = average of the four corners.
      var r = 0, g = 0, b = 0, n = 0;
      const patch = 24;
      for (final (cx, cy) in [
        (0, 0),
        (w - patch, 0),
        (0, h - patch),
        (w - patch, h - patch),
      ]) {
        for (var y = cy; y < cy + patch; y++) {
          for (var x = cx; x < cx + patch; x++) {
            final i = (y * w + x) * 4;
            r += rgba[i];
            g += rgba[i + 1];
            b += rgba[i + 2];
            n++;
          }
        }
      }
      r ~/= n;
      g ~/= n;
      b ~/= n;
      final bgLum = 0.299 * r + 0.587 * g + 0.114 * b;

      // Cut the light artwork out of the background: alpha = how much brighter
      // than the background a pixel is (with a dead-zone for compression noise).
      final out = Uint8List(w * h * 4);
      var minX = w, minY = h, maxX = 0, maxY = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final i = (y * w + x) * 4;
          final lum =
              0.299 * rgba[i] + 0.587 * rgba[i + 1] + 0.114 * rgba[i + 2];
          var t = (lum - bgLum) / (255 - bgLum);
          t = ((t - 0.10) / 0.55).clamp(0.0, 1.0);
          if (t <= 0) continue;
          final a = (t * 255).round();
          // White, premultiplied by alpha.
          out[i] = a;
          out[i + 1] = a;
          out[i + 2] = a;
          out[i + 3] = a;
          if (a > 24) {
            minX = math.min(minX, x);
            maxX = math.max(maxX, x);
            minY = math.min(minY, y);
            maxY = math.max(maxY, y);
          }
        }
      }

      final cutout = await _fromPixels(out, w, h);
      final box = ui.Rect.fromLTRB(
        minX.toDouble(),
        minY.toDouble(),
        maxX + 1.0,
        maxY + 1.0,
      );
      final scale = (_canvas * _artworkShare) / math.max(box.width, box.height);
      final dw = box.width * scale, dh = box.height * scale;
      final dest = ui.Rect.fromLTWH(
        (_canvas - dw) / 2,
        (_canvas - dh) / 2,
        dw,
        dh,
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        cutout,
        box,
        dest,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      final result = await recorder.endRecording().toImage(_canvas, _canvas);
      final png = await result.toByteData(format: ui.ImageByteFormat.png);
      File(
        'assets/logo/app_icon_foreground.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());

      // Preview (not shipped): the foreground over the background colour, with
      // the ~66% window Android guarantees drawn as a faint outline.
      final pRecorder = ui.PictureRecorder();
      final pCanvas = ui.Canvas(pRecorder);
      pCanvas.drawRect(
        ui.Rect.fromLTWH(0, 0, _canvas.toDouble(), _canvas.toDouble()),
        ui.Paint()..color = ui.Color.fromARGB(255, r, g, b),
      );
      pCanvas.drawImage(result, ui.Offset.zero, ui.Paint());
      pCanvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          ui.Rect.fromCenter(
            center: const ui.Offset(_canvas / 2, _canvas / 2),
            width: _canvas * 0.667,
            height: _canvas * 0.667,
          ),
          const ui.Radius.circular(150),
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const ui.Color(0x88FF4081),
      );
      final preview = await pRecorder.endRecording().toImage(_canvas, _canvas);
      final previewPng = await preview.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Directory('build').createSync(recursive: true);
      File(
        'build/icon_preview.png',
      ).writeAsBytesSync(previewPng!.buffer.asUint8List());

      String hex(int v) => v.toRadixString(16).padLeft(2, '0').toUpperCase();
      // ignore: avoid_print
      print(
        '\nadaptive_icon_background: "#${hex(r)}${hex(g)}${hex(b)}"'
        '   (artwork box ${box.width.round()}x${box.height.round()})\n',
      );
    });
  });
}

Future<ui.Image> _fromPixels(Uint8List pixels, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
