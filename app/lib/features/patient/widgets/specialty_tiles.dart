import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_assets.dart';

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

/// Horizontally scrolling row (home screen).
class SpecialtyRow extends StatelessWidget {
  const SpecialtyRow({super.key, required this.onSelected});

  final ValueChanged<SpecialtyMeta> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 122,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kSpecialtyMeta.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SpecialtyTile(
          meta: kSpecialtyMeta[i],
          index: i,
          onTap: () => onSelected(kSpecialtyMeta[i]),
        ),
      ),
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
