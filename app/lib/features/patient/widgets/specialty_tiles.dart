import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';

class SpecialtyMeta {
  const SpecialtyMeta(this.name, this.label, this.icon);

  /// Canonical value stored in the database (matches kSpecialties).
  final String name;

  /// Short label that fits under a tile.
  final String label;
  final IconData icon;
}

const kSpecialtyMeta = <SpecialtyMeta>[
  SpecialtyMeta('General Practice', 'General', LucideIcons.stethoscope),
  SpecialtyMeta('Pediatrics', 'Children', LucideIcons.baby),
  SpecialtyMeta('Obstetrics & Gynaecology', 'OB/GYN', LucideIcons.venus),
  SpecialtyMeta('Internal Medicine', 'Internal', LucideIcons.activity),
  SpecialtyMeta('Dermatology', 'Skin', LucideIcons.sparkles),
  SpecialtyMeta('Psychiatry/Mental Health', 'Mental health', LucideIcons.brain),
  SpecialtyMeta('Cardiology', 'Heart', LucideIcons.heartPulse),
  SpecialtyMeta('ENT', 'ENT', LucideIcons.ear),
  SpecialtyMeta('Orthopedics', 'Bones', LucideIcons.bone),
];

SpecialtyMeta specialtyMetaFor(String name) => kSpecialtyMeta.firstWhere(
  (m) => m.name == name,
  orElse: () => SpecialtyMeta(name, name, LucideIcons.stethoscope),
);

/// One rounded specialty tile. Alternates blue/teal tints by [index] so a
/// row reads as a varied set while staying inside the brand palette.
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
    final teal = index.isOdd;
    final tint = teal ? AppColors.accentTealSoft : AppColors.primarySoft;
    final accent = teal ? AppColors.accentTeal : AppColors.primary;

    return Semantics(
      button: true,
      selected: selected,
      label: meta.name,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: width,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? accent : AppColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? accent : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withValues(alpha: 0.2) : tint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  meta.icon,
                  size: 21,
                  color: selected ? Colors.white : accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meta.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? Colors.white : AppColors.ink,
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

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kSpecialtyMeta.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => SpecialtyTile(
          meta: kSpecialtyMeta[i],
          index: i,
          onTap: () => onSelected(kSpecialtyMeta[i].name),
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
      runSpacing: 10,
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
