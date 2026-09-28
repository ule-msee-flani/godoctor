import 'package:flutter/widgets.dart';

/// Bottom edge that rises gently towards the middle, so the white page
/// below seems to lift into the photo above it (sign-in and profile
/// headers).
class InwardCurveClipper extends CustomClipper<Path> {
  const InwardCurveClipper({this.depth = 30});

  final double depth;

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..quadraticBezierTo(w / 2, h - depth * 2, 0, h)
      ..close();
  }

  @override
  bool shouldReclip(InwardCurveClipper oldClipper) => oldClipper.depth != depth;
}
