import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_assets.dart';

/// Photo edge to edge across the top of the screen (about half its height)
/// with a gently curved bottom edge; the page below it scrolls up over the
/// photo on small phones, like the specialty pages.
class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({
    super.key,
    required this.image,
    required this.child,
    this.onBack,
    this.alignment = Alignment.center,
    this.heightFactor = 0.46,
  });

  /// Asset path without extension (any of png/jpg/webp).
  final String image;
  final Widget child;
  final VoidCallback? onBack;

  /// Which part of the photo to keep when it's cropped to the space.
  final Alignment alignment;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * heightFactor).clamp(
      240.0,
      460.0,
    );
    final asset = AppAssets.find(image);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: height,
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: onBack == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Center(
                        child: IconButton.filled(
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.92,
                            ),
                            foregroundColor: AppColors.ink,
                          ),
                          icon: const Icon(LucideIcons.arrowLeft, size: 20),
                          onPressed: onBack,
                        ),
                      ),
                    ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: ClipPath(
                  clipper: const InwardCurveClipper(),
                  child: asset == null
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                          ),
                        )
                      : Image.asset(
                          asset,
                          fit: BoxFit.cover,
                          alignment: alignment,
                          cacheWidth: 1400,
                          errorBuilder: (_, _, _) => const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppColors.heroGradient,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SliverFillRemaining(hasScrollBody: false, child: child),
          ],
        ),
      ),
    );
  }
}

/// Bottom edge that rises gently towards the middle, so the white page
/// below seems to lift into the photo.
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

/// The app's launcher icon, as a rounded square.
class AppIconMark extends StatelessWidget {
  const AppIconMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets.find('assets/logo/app_icon');
    final radius = BorderRadius.circular(size * 0.24);
    return Semantics(
      label: 'GoDoctor',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
              color: Color(0x2600174C),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox.square(
            dimension: size,
            child: asset == null
                ? const ColoredBox(color: Color(0xFF00174C))
                : Image.asset(
                    asset,
                    fit: BoxFit.cover,
                    cacheWidth: (size * 3).round(),
                  ),
          ),
        ),
      ),
    );
  }
}
