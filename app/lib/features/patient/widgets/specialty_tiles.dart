import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_assets.dart';
import '../../../core/widgets/motion.dart';

class SpecialtyMeta {
  const SpecialtyMeta(this.name, this.label, this.slug, this.icon);

  /// Canonical value stored in the database (matches kSpecialties).
  final String name;

  /// Short label that fits under a tile.
  final String label;

  /// Also the picture file name: `assets/images/specialties/SLUG.png`
  /// (any of png/jpg/webp), and the page route `/patient/specialty/SLUG`.
  final String slug;

  /// Only shown until a picture has been supplied.
  final IconData icon;

  /// Title on the big picture cards (home).
  String get title => switch (slug) {
    'general' => 'General Practice',
    'children' => 'Children\'s Health',
    'obgyn' => 'Women\'s Health',
    'internal' => 'Internal Medicine',
    'skin' => 'Skin Care',
    'mental-health' => 'Mental Health',
    'heart' => 'Heart Health',
    'ent' => 'Ear, Nose & Throat',
    'bones' => 'Bones & Joints',
    _ => name,
  };

  String get imageBase => 'assets/images/specialties/$slug';

  /// Optional wide picture for the top of the specialty page. Falls back to
  /// the tile picture when not supplied.
  String get heroBase => 'assets/images/specialties/${slug}_hero';
}

const kSpecialtyMeta = <SpecialtyMeta>[
  SpecialtyMeta(
    'General Practice',
    'General',
    'general',
    LucideIcons.stethoscope,
  ),
  SpecialtyMeta('Pediatrics', 'Children', 'children', LucideIcons.baby),
  SpecialtyMeta(
    'Obstetrics & Gynaecology',
    'OB/GYN',
    'obgyn',
    LucideIcons.venus,
  ),
  SpecialtyMeta(
    'Internal Medicine',
    'Internal',
    'internal',
    LucideIcons.activity,
  ),
  SpecialtyMeta('Dermatology', 'Skin', 'skin', LucideIcons.sparkles),
  SpecialtyMeta(
    'Psychiatry/Mental Health',
    'Mental health',
    'mental-health',
    LucideIcons.brain,
  ),
  SpecialtyMeta('Cardiology', 'Heart', 'heart', LucideIcons.heartPulse),
  SpecialtyMeta('ENT', 'ENT', 'ent', LucideIcons.ear),
  SpecialtyMeta('Orthopedics', 'Bones', 'bones', LucideIcons.bone),
];

SpecialtyMeta specialtyMetaFor(String name) => kSpecialtyMeta.firstWhere(
  (m) => m.name == name,
  orElse: () => SpecialtyMeta(name, name, '', LucideIcons.stethoscope),
);

SpecialtyMeta? specialtyMetaForSlug(String slug) {
  for (final m in kSpecialtyMeta) {
    if (m.slug == slug) return m;
  }
  return null;
}

/// The specialty's picture (rounded square), or a plain black icon on a
/// neutral tile when no picture has been supplied yet.
class SpecialtyImage extends StatelessWidget {
  const SpecialtyImage({
    super.key,
    required this.meta,
    required this.size,
    this.index = 0,
    this.radius = 18,
  });

  final SpecialtyMeta meta;
  final double size;
  final int index;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final found = AppAssets.find(meta.imageBase);

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: found != null
            ? Image.asset(
                found,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Center(
      child: Icon(meta.icon, size: size * 0.4, color: AppColors.ink),
    ),
  );
}

/// One specialty tile: picture on top, label underneath.
class SpecialtyTile extends StatelessWidget {
  const SpecialtyTile({
    super.key,
    required this.meta,
    required this.index,
    required this.onTap,
    this.selected = false,
    this.width = 84,
  });

  final SpecialtyMeta meta;
  final int index;
  final VoidCallback onTap;
  final bool selected;
  final double width;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.ink;
    final imageSize = width - 8;

    return Semantics(
      button: true,
      selected: selected,
      label: meta.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SpecialtyImage(
                      meta: meta,
                      size: imageSize - 6,
                      index: index,
                    ),
                    if (selected)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                meta.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? accent : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home: specialties as big picture cards, two to a page. Swipe sideways
/// for the next two; the dashes underneath show where you are.
class SpecialtyCarousel extends StatefulWidget {
  const SpecialtyCarousel({super.key, required this.onSelected});

  final ValueChanged<SpecialtyMeta> onSelected;

  @override
  State<SpecialtyCarousel> createState() => _SpecialtyCarouselState();
}

class _SpecialtyCarouselState extends State<SpecialtyCarousel> {
  final _pages = PageController();
  int _page = 0;

  static final _pairs = [
    for (var i = 0; i < kSpecialtyMeta.length; i += 2)
      kSpecialtyMeta.sublist(
        i,
        i + 2 > kSpecialtyMeta.length ? kSpecialtyMeta.length : i + 2,
      ),
  ];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth.isFinite ? c.maxWidth : 400) - 40;
        final cardHeight = (width / 2.25).clamp(120.0, 190.0);
        const gap = 14.0;
        return Column(
          children: [
            SizedBox(
              height: cardHeight * 2 + gap,
              child: PageView.builder(
                controller: _pages,
                itemCount: _pairs.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, p) {
                  final pair = _pairs[p];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        for (var i = 0; i < pair.length; i++) ...[
                          if (i > 0) const SizedBox(height: gap),
                          SizedBox(
                            height: cardHeight,
                            child: SpecialtyCard(
                              meta: pair[i],
                              onTap: () => widget.onSelected(pair[i]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            PageDashes(count: _pairs.length, current: _page),
          ],
        );
      },
    );
  }
}

/// One specialty as a picture card: its photo filling the card, the icon
/// top-left, the name bottom-left and an arrow on the right.
class SpecialtyCard extends StatelessWidget {
  const SpecialtyCard({super.key, required this.meta, required this.onTap});

  final SpecialtyMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = AppAssets.find(meta.imageBase);
    return Semantics(
      button: true,
      label: meta.name,
      child: Pressable(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (photo != null)
                Image.asset(
                  photo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _fallback(),
                )
              else
                _fallback(),
              // Darker towards the bottom-left so the white text reads on
              // any photo.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0x14000000), Color(0x9E000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                top: 16,
                child: Icon(meta.icon, color: Colors.white, size: 30),
              ),
              Positioned(
                left: 18,
                right: 56,
                bottom: 16,
                child: Text(
                  meta.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
                  ),
                ),
              ),
              const Positioned(
                right: 16,
                bottom: 18,
                child: Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.heroGradient),
    child: Align(
      alignment: const Alignment(0.8, -0.2),
      child: Icon(meta.icon, size: 96, color: const Color(0x22FFFFFF)),
    ),
  );
}

/// Page dashes: a long dark one for the current page, short grey ones for
/// the rest.
class PageDashes extends StatelessWidget {
  const PageDashes({super.key, required this.count, required this.current});

  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 30 : 14,
            height: 3,
            decoration: BoxDecoration(
              color: i == current ? AppColors.ink : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}

/// Wrapping selectable grid (intake form).
class SpecialtyGrid extends StatelessWidget {
  const SpecialtyGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (var i = 0; i < kSpecialtyMeta.length; i++)
          SpecialtyTile(
            meta: kSpecialtyMeta[i],
            index: i,
            selected: kSpecialtyMeta[i].name == selected,
            onTap: () => onSelected(kSpecialtyMeta[i].name),
          ),
      ],
    );
  }
}
