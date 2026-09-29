import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/drug.dart';

/// A shelf of over-the-counter medicines for one everyday problem.
class SymptomShelf {
  const SymptomShelf(this.label, this.emoji, this.keywords);

  final String label;
  final String emoji;

  /// Medicine names (or parts of them) that belong on this shelf.
  final List<String> keywords;
}

const kSymptomShelves = <SymptomShelf>[
  SymptomShelf('Headache', '🤕', ['paracetamol', 'ibuprofen', 'aspirin']),
  SymptomShelf('Fever', '🤒', ['paracetamol', 'ibuprofen']),
  SymptomShelf('Cold & flu', '🤧', [
    'cetirizine',
    'chlorpheniramine',
    'loratadine',
    'xylometazoline',
    'nasal',
    'vitamin c',
    'paracetamol',
  ]),
  SymptomShelf('Cough', '😷', ['dextromethorphan', 'cough']),
  SymptomShelf('Heartburn', '🔥', [
    'magnesium trisilicate',
    'calcium carbonate',
    'omeprazole',
    'ranitidine',
    'antacid',
  ]),
  SymptomShelf('Allergy', '🌼', [
    'cetirizine',
    'loratadine',
    'chlorpheniramine',
  ]),
  SymptomShelf('Diarrhoea', '💧', ['oral rehydration', 'zinc', 'loperamide']),
  SymptomShelf('Constipation', '🌿', ['bisacodyl', 'lactulose']),
  SymptomShelf('Aches & pain', '💪', [
    'ibuprofen',
    'diclofenac',
    'paracetamol',
    'aspirin',
  ]),
  SymptomShelf('Skin & itch', '🧴', [
    'hydrocortisone',
    'clotrimazole',
    'permethrin',
    'benzyl benzoate',
    'calamine',
  ]),
  SymptomShelf('Nausea', '🤢', ['metoclopramide']),
  SymptomShelf('Eyes', '👁️', ['eye']),
  SymptomShelf('Worms', '🪱', ['albendazole', 'mebendazole']),
  SymptomShelf('Vitamins', '💊', [
    'vitamin',
    'multivitamin',
    'ferrous',
    'folic',
    'zinc',
  ]),
];

/// The medicines on [shelf]: no prescription needed, name matching one of
/// its keywords. Pure, for tests.
List<Drug> drugsForShelf(List<Drug> all, SymptomShelf shelf) => [
  for (final d in all)
    if (!d.requiresPrescription &&
        shelf.keywords.any(
          (k) => [
            d.genericName,
            ...d.brandNames,
          ].any((n) => n.toLowerCase().contains(k)),
        ))
      d,
];

/// Order Medicine's header: pharmacies near you, upload a prescription,
/// and shop by symptom.
class ShopHeader extends StatelessWidget {
  const ShopHeader({super.key, required this.shelf, required this.onShelf});

  final SymptomShelf? shelf;
  final ValueChanged<SymptomShelf?> onShelf;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: _Tile(
                  gradient: AppColors.skyGradient,
                  icon: LucideIcons.store,
                  color: AppColors.primary,
                  title: 'Pharmacies',
                  subtitle: 'Near you',
                  onTap: () => context.push('/patient/pharmacies'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Tile(
                  gradient: AppColors.lavenderGradient,
                  icon: LucideIcons.fileUp,
                  color: AppColors.lavender,
                  title: 'Prescription',
                  subtitle: 'Upload & order',
                  onTap: () => context.push('/patient/prescriptions/upload'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  shelf == null
                      ? 'Shop by symptom'
                      : 'For ${shelf!.label.toLowerCase()}',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (shelf != null)
                TextButton.icon(
                  onPressed: () => onShelf(null),
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text('Show all'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: kSymptomShelves.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = kSymptomShelves[i];
              final on = shelf == s;
              return Semantics(
                button: true,
                selected: on,
                label: s.label,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 78,
                  decoration: BoxDecoration(
                    color: on ? AppColors.primary : AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: on ? AppColors.primary : AppColors.border,
                    ),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onShelf(on ? null : s);
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.emoji, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              s.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.labelSmall?.copyWith(
                                color: on ? Colors.white : AppColors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.gradient,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Gradient gradient;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(gradient: gradient),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
