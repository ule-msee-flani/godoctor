import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/app_assets.dart';

/// Shows a real image from `assets/` when one has been supplied, and a
/// designed placeholder panel when it hasn't.
///
/// [assetPath] is the file path *without* caring about the extension: save
/// the picture as .png, .jpg or .webp and it is picked up automatically.
/// See `assets/README.md` for the full list of file names.
///
/// [overlay], if set, is painted on top of the picture (real or placeholder).
/// The home carousel uses it so every banner keeps its brand colour tint
/// with the photo showing through underneath.
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.assetPath,
    this.height,
    this.width,
    this.borderRadius = 24,
    this.fit = BoxFit.cover,
    required this.placeholderIcon,
    required this.placeholderLabel,
    this.gradient = AppColors.primaryGradient,
    this.showPlaceholderContent = true,
    this.overlay,
    this.alignment = Alignment.center,
    this.zoom = 1,
  });

  final String assetPath;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;
  final String placeholderLabel;
  final Gradient gradient;

  /// Set false when the image is a backdrop behind other content, so the
  /// fallback panel is just the gradient (no centred icon/filename hint).
  final bool showPlaceholderContent;
  final Gradient? overlay;

  /// Which part of the picture to keep when it is cropped to fit (e.g.
  /// `Alignment(0, -1)` keeps the top edge, so a portrait photo cropped into a
  /// wide strip shows the head rather than the middle of the body).
  final Alignment alignment;

  /// Enlarges the picture around [alignment] before cropping (1 = no zoom).
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final found = AppAssets.find(assetPath);
    Widget placeholder() => _Placeholder(
      icon: placeholderIcon,
      label: placeholderLabel,
      gradient: gradient,
      showContent: showPlaceholderContent,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (found == null)
              placeholder()
            else
              Transform.scale(
                scale: zoom,
                alignment: alignment,
                child: Image.asset(
                  found,
                  fit: fit,
                  alignment: alignment,
                  errorBuilder: (_, _, _) => placeholder(),
                ),
              ),
            if (overlay != null)
              DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.showContent,
  });

  final IconData icon;
  final String label;
  final Gradient gradient;
  final bool showContent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(right: -20, top: -20, child: _softCircle(90)),
          Positioned(left: -30, bottom: -30, child: _softCircle(120)),
          if (showContent)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 40),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _softCircle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}
