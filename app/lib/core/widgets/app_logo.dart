import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../utils/app_assets.dart';

/// The GoDoctor logo. Uses `assets/logo/logo.png` (any of png/jpg/webp) when
/// supplied -- a transparent-background lockup, ideally with a wide aspect --
/// and a simple drawn mark plus wordmark until then.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context) {
    final asset = AppAssets.find('assets/logo/logo');
    if (asset != null) {
      return Image.asset(
        asset,
        height: height,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        errorBuilder: (_, _, _) => _fallback(context),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(height * 0.3),
          ),
          child: Icon(
            LucideIcons.heartPulse,
            color: Colors.white,
            size: height * 0.55,
          ),
        ),
        const SizedBox(width: 12),
        Text('GoDoctor', style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}
