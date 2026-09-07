import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Displays a real asset image from `assets/images/` when present, and
/// falls back to a designed placeholder panel when it isn't (yet) supplied.
///
/// The app ships without real photography — see `app/IMAGES.md` for the
/// full shot list. Drop a file at the given [assetPath] and it renders
/// automatically on next hot-restart/build, no code changes needed.
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
  });

  final String assetPath;
  final double? height;
  final double? width;
  final double borderRadius;
  final BoxFit fit;
  final IconData placeholderIcon;
  final String placeholderLabel;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        width: width,
        child: Image.asset(
          assetPath,
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _Placeholder(
            icon: placeholderIcon,
            label: placeholderLabel,
            gradient: gradient,
          ),
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
  });

  final IconData icon;
  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: _softCircle(90),
          ),
          Positioned(
            left: -30,
            bottom: -30,
            child: _softCircle(120),
          ),
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
