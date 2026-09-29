import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/drug.dart';
import '../../data/models/medicine_category.dart';
import '../../data/providers/repository_providers.dart';
import '../patient/widgets/medicine_image.dart';
import '../patient/widgets/medicine_info_sheet.dart';

/// The whole medicine catalogue with chemist pack photos attached. Shared by
/// every screen that shows the gallery (patient, doctor, chemist).
final medicineCatalogProvider = FutureProvider.autoDispose<List<Drug>>(
  (ref) => ref.watch(drugRepositoryProvider).fetchCatalog(),
);

/// Medicines whose generic or brand name contains [query].
List<Drug> filterMedicines(List<Drug> drugs, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return drugs;
  return drugs
      .where(
        (d) =>
            d.genericName.toLowerCase().contains(q) ||
            d.brandNames.any((b) => b.toLowerCase().contains(q)),
      )
      .toList();
}

/// Builds the action row at the bottom of the showcase for the featured
/// medicine -- "Find chemists" for patients, "Prescribe" for doctors,
/// "Add to my stock" for chemists.
typedef ShowcaseFooterBuilder =
    Widget Function(BuildContext context, Drug drug);

/// The medicine gallery used across the app: a large showcase of one
/// medicine on top and, below it, shelves by form (tablets, syrups,
/// creams...). Scroll the shelves vertically to change category and
/// sideways to browse a shelf; tap a medicine to feature it.
///
/// When [query] is not empty the shelves are replaced by matching results.
class MedicineGallery extends StatefulWidget {
  const MedicineGallery({
    super.key,
    required this.drugs,
    required this.footerBuilder,
    this.query = '',
    this.markedIds = const {},
    this.markIcon = LucideIcons.check,
    this.markColor = AppColors.success,
    this.showcaseHeight,
    this.emptyMessage = 'No medicines to show.',
    this.onSelected,
  });

  final List<Drug> drugs;
  final ShowcaseFooterBuilder footerBuilder;
  final String query;

  /// Medicines to badge on their thumbnail (e.g. already prescribed, or in
  /// this chemist's stock).
  final Set<String> markedIds;
  final IconData markIcon;
  final Color markColor;

  /// Fixed showcase height; defaults to ~36% of the screen.
  final double? showcaseHeight;
  final String emptyMessage;
  final ValueChanged<Drug>? onSelected;

  @override
  State<MedicineGallery> createState() => _MedicineGalleryState();
}

class _MedicineGalleryState extends State<MedicineGallery> {
  String? _selectedId;

  void _select(Drug d) {
    setState(() => _selectedId = d.id);
    widget.onSelected?.call(d);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.drugs.isEmpty) {
      return EmptyView(message: widget.emptyMessage, icon: LucideIcons.pill);
    }

    final shelves = <MedicineCategory, List<Drug>>{};
    for (final d in widget.drugs) {
      shelves.putIfAbsent(MedicineCategory.fromForm(d.form), () => []).add(d);
    }
    final orderedShelves = [
      for (final c in MedicineCategory.values)
        if (shelves[c]?.isNotEmpty ?? false) (c, shelves[c]!),
    ];

    final featured =
        widget.drugs.where((d) => d.id == _selectedId).firstOrNull ??
        orderedShelves.first.$2.first;
    final showResults = widget.query.trim().isNotEmpty;

    final height =
        widget.showcaseHeight ??
        (MediaQuery.of(context).size.height * 0.36).clamp(250.0, 330.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.97, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: MedicineShowcase(
              key: ValueKey(featured.id),
              drug: featured,
              height: height,
              footer: widget.footerBuilder(context, featured),
            ),
          ),
        ),
        Expanded(
          child: showResults
              ? _SearchResults(
                  results: filterMedicines(widget.drugs, widget.query),
                  selectedId: featured.id,
                  onSelect: _select,
                  markedIds: widget.markedIds,
                  markIcon: widget.markIcon,
                  markColor: widget.markColor,
                )
              : _Shelves(
                  shelves: orderedShelves,
                  selectedId: featured.id,
                  onSelect: _select,
                  markedIds: widget.markedIds,
                  markIcon: widget.markIcon,
                  markColor: widget.markColor,
                ),
        ),
      ],
    );
  }
}

/// The featured medicine: its photo fills the whole card edge to edge,
/// fading to white at the bottom where the name, details and [footer] sit.
class MedicineShowcase extends StatelessWidget {
  const MedicineShowcase({
    super.key,
    required this.drug,
    required this.height,
    required this.footer,
  });

  final Drug drug;
  final double height;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final category = MedicineCategory.fromForm(drug.form);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          MedicineImage.fill(drug: drug),
          // White fade so the text below stays readable over any photo.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.30, 0.62, 1.0],
                colors: [
                  Color(0x00FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0xF2FFFFFF),
                  Color(0xFFFFFFFF),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    MedicinePill(icon: category.icon, label: category.label),
                    drug.requiresPrescription
                        ? const MedicinePill(
                            icon: LucideIcons.fileText,
                            label: 'Prescription needed',
                          )
                        : const MedicinePill(
                            icon: LucideIcons.badgeCheck,
                            label: 'No prescription needed',
                          ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        drug.genericName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: AppColors.ink,
                      ),
                      onPressed: () => showMedicineInfoSheet(context, drug),
                      icon: const Icon(LucideIcons.info, size: 16),
                      label: const Text('About'),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (drug.form != null) drug.form!,
                    if (drug.brandNames.isNotEmpty)
                      drug.brandNames.take(2).join(', '),
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 10),
                footer,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small white label over the showcase photo: black icon and text.
class MedicinePill extends StatelessWidget {
  const MedicinePill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact search box for galleries that live inside a screen (the app bar
/// search is used on the patient's full-screen gallery instead).
class MedicineSearchField extends StatelessWidget {
  const MedicineSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search medicines',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        prefixIcon: const Icon(LucideIcons.search, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

/// Vertical list of shelves; each shelf scrolls sideways.
class _Shelves extends StatelessWidget {
  const _Shelves({
    required this.shelves,
    required this.selectedId,
    required this.onSelect,
    required this.markedIds,
    required this.markIcon,
    required this.markColor,
  });

  final List<(MedicineCategory, List<Drug>)> shelves;
  final String selectedId;
  final ValueChanged<Drug> onSelect;
  final Set<String> markedIds;
  final IconData markIcon;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: shelves.length,
      itemBuilder: (context, i) {
        final (category, drugs) = shelves[i];
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        category.icon,
                        size: 16,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        category.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${drugs.length}', style: theme.bodySmall),
                    const Spacer(),
                    if (drugs.length > 3)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Swipe', style: theme.bodySmall),
                          const SizedBox(width: 2),
                          const Icon(
                            LucideIcons.chevronRight,
                            size: 14,
                            color: AppColors.inkFaint,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: drugs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, j) => MedicineThumb(
                    drug: drugs[j],
                    selected: drugs[j].id == selectedId,
                    marked: markedIds.contains(drugs[j].id),
                    markIcon: markIcon,
                    markColor: markColor,
                    onTap: () => onSelect(drugs[j]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.selectedId,
    required this.onSelect,
    required this.markedIds,
    required this.markIcon,
    required this.markColor,
  });

  final List<Drug> results;
  final String selectedId;
  final ValueChanged<Drug> onSelect;
  final Set<String> markedIds;
  final IconData markIcon;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const EmptyView(
        message: 'No medicines match your search.',
        icon: LucideIcons.searchX,
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 14,
        children: [
          for (final d in results)
            MedicineThumb(
              drug: d,
              selected: d.id == selectedId,
              marked: markedIds.contains(d.id),
              markIcon: markIcon,
              markColor: markColor,
              onTap: () => onSelect(d),
            ),
        ],
      ),
    );
  }
}

/// One medicine on a shelf: picture with an Rx badge (top right) and an
/// optional mark badge (bottom right), name underneath.
class MedicineThumb extends StatelessWidget {
  const MedicineThumb({
    super.key,
    required this.drug,
    required this.selected,
    required this.onTap,
    this.marked = false,
    this.markIcon = LucideIcons.check,
    this.markColor = AppColors.success,
  });

  final Drug drug;
  final bool selected;
  final VoidCallback onTap;
  final bool marked;
  final IconData markIcon;
  final Color markColor;

  @override
  Widget build(BuildContext context) {
    final category = MedicineCategory.fromForm(drug.form);
    return Semantics(
      button: true,
      selected: selected,
      label: drug.genericName,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: SizedBox(
          width: 92,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? category.accent : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    MedicineImage(drug: drug, size: 80, radius: 18),
                    if (drug.requiresPrescription)
                      Positioned(
                        right: -3,
                        top: -3,
                        child: _Badge(
                          icon: LucideIcons.fileText,
                          color: AppColors.warning,
                        ),
                      ),
                    if (marked)
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: _Badge(icon: markIcon, color: markColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                drug.genericName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? category.accent : AppColors.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // White dot with a black icon; the thin ring keeps the meaning
    // (amber = prescription needed, green/blue = in stock / prescribed).
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 10, color: AppColors.ink),
    );
  }
}

class MedicineGallerySkeleton extends StatelessWidget {
  const MedicineGallerySkeleton({super.key, this.showcaseHeight = 280});

  final double showcaseHeight;

  @override
  Widget build(BuildContext context) {
    // Cut off at the bottom in a short space (e.g. the call's half-height
    // panel) instead of overflowing.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: showcaseHeight, radius: 28),
          const SizedBox(height: 22),
          const Skeleton(width: 140, height: 16),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const Skeleton(width: 92, height: 104, radius: 20),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
