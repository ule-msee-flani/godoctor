import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_image.dart';

class _Banner {
  const _Banner({
    required this.title,
    required this.cta,
    required this.route,
    required this.image,
    required this.icon,
    required this.gradient,
    this.alignment = Alignment.center,
  });

  final String title;
  final String cta;
  final String route;
  final String image;
  final IconData icon;
  final Gradient gradient;

  /// Crop focus for the photo (see AppImage.alignment).
  final Alignment alignment;
}

const _banners = <_Banner>[
  _Banner(
    title: 'Feeling unwell?\nSee a doctor in minutes',
    cta: 'See a doctor',
    route: '/patient/intake',
    image: 'assets/images/banners/banner_doctor',
    // Square portrait: keep the face, not the chest.
    alignment: Alignment(0.3, -0.85),
    icon: LucideIcons.stethoscope,
    gradient: AppColors.primaryGradient,
  ),
  _Banner(
    title: 'Medicine from chemists\nnear you',
    cta: 'Order medicine',
    route: '/patient/medicine-search',
    image: 'assets/images/banners/banner_pharmacy',
    alignment: Alignment(0, -0.3),
    icon: LucideIcons.pill,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.accentTeal, AppColors.primaryDark],
    ),
  ),
  _Banner(
    title: 'Keep every prescription\nin one place',
    cta: 'My prescriptions',
    route: '/patient/prescriptions',
    image: 'assets/images/banners/banner_prescriptions',
    // Tall page: keep the top, with the cross and the Rx.
    alignment: Alignment(0, -0.6),
    icon: LucideIcons.fileText,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.primaryDark, AppColors.primaryDarker],
    ),
  ),
];

/// Turns a solid brand gradient into a translucent overlay for a photo.
Gradient _tint(Gradient g) {
  final linear = g as LinearGradient;
  final n = linear.colors.length;
  return LinearGradient(
    begin: linear.begin,
    end: linear.end,
    colors: [
      for (var i = 0; i < n; i++)
        linear.colors[i].withValues(alpha: 0.92 - 0.37 * (i / (n - 1))),
    ],
  );
}

/// Auto-advancing banner slider for the home screen. Each banner is a real
/// image (drop the file in assets/images/banners/) with a readable text scrim on
/// top; without the image it falls back to a branded gradient.
class PromoBannerCarousel extends StatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  State<PromoBannerCarousel> createState() => _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends State<PromoBannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _BannerCard(banner: _banners[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? AppColors.primary
                      : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(banner.route),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The photo sits at the back; the banner's brand colour is laid over
          // it as a translucent tint (strongest behind the text, easing off
          // to the right so the picture still shows through).
          AppImage(
            assetPath: banner.image,
            borderRadius: 24,
            placeholderIcon: banner.icon,
            placeholderLabel: banner.image,
            gradient: banner.gradient,
            showPlaceholderContent: false,
            overlay: _tint(banner.gradient),
            alignment: banner.alignment,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.white, height: 1.25),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              banner.cta,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: AppColors.primaryDark,
                                    fontSize: 13,
                                  ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.arrowRight,
                              size: 14,
                              color: AppColors.primaryDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  banner.icon,
                  size: 54,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
