import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/medicine_category.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/medicine_image.dart';
import '../widgets/medicine_info_sheet.dart';

final _catalogProvider = FutureProvider.autoDispose<List<Drug>>(
  (ref) => ref.watch(drugRepositoryProvider).fetchCatalog(),
);

/// Stock at verified chemists for the medicine being showcased.
final _stockProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, drugId) =>
          ref.watch(drugRepositoryProvider).findStockForDrug(drugId),
    );

/// "Order medicine": a product showcase at the top and, below it, shelves of
/// medicines. Scroll the shelves vertically to change category (tablets,
/// syrups, creams...) and sideways to browse the medicines on a shelf. Tap
/// one to feature it, then find chemists that stock it.
class MedicineSearchScreen extends ConsumerStatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  ConsumerState<MedicineSearchScreen> createState() =>
      _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends ConsumerState<MedicineSearchScreen> {
  Drug? _selected;
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _select(Drug drug) => setState(() => _selected = drug);

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_catalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search medicines',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              )
            : const Text('Order Medicine'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? LucideIcons.x : LucideIcons.search),
            onPressed: _toggleSearch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: catalog.when(
        loading: () => const _GallerySkeleton(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(_catalogProvider),
        ),
        data: (drugs) {
          if (drugs.isEmpty) {
            return const EmptyView(
              message: 'The medicine catalogue is empty.',
              icon: LucideIcons.pill,
            );
          }

          final shelves = <MedicineCategory, List<Drug>>{};
          for (final d in drugs) {
            shelves
                .putIfAbsent(MedicineCategory.fromForm(d.form), () => [])
                .add(d);
          }
          final orderedShelves = [
            for (final c in MedicineCategory.values)
              if (shelves[c]?.isNotEmpty ?? false) (c, shelves[c]!),
          ];

          final featured = _selected ?? orderedShelves.first.$2.first;
          final query = _searchCtrl.text.trim().toLowerCase();
          final showResults = _searching && query.isNotEmpty;
          final results = showResults
              ? drugs
                    .where(
                      (d) =>
                          d.genericName.toLowerCase().contains(query) ||
                          d.brandNames.any(
                            (b) => b.toLowerCase().contains(query),
                          ),
                    )
                    .toList()
              : const <Drug>[];

          final screenHeight = MediaQuery.of(context).size.height;
          final showcaseHeight = (screenHeight * 0.36).clamp(250.0, 330.0);

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
                  child: _Showcase(
                    key: ValueKey(featured.id),
                    drug: featured,
                    height: showcaseHeight,
                  ),
                ),
              ),
              Expanded(
                child: showResults
                    ? _SearchResults(
                        results: results,
                        selectedId: featured.id,
                        onSelect: _select,
                      )
                    : _Shelves(
                        shelves: orderedShelves,
                        selectedId: featured.id,
                        onSelect: _select,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Showcase extends ConsumerWidget {
  const _Showcase({super.key, required this.drug, required this.height});

  final Drug drug;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final category = MedicineCategory.fromForm(drug.form);
    final stock = ref.watch(_stockProvider(drug.id));
    final imageSize = (height * 0.42).clamp(96.0, 150.0);

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [category.soft, AppColors.white],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: category.accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(
                      icon: category.icon,
                      label: category.label,
                      color: category.accent,
                    ),
                    const Spacer(),
                    drug.requiresPrescription
                        ? const _Pill(
                            icon: LucideIcons.fileText,
                            label: 'Prescription needed',
                            color: AppColors.warning,
                          )
                        : const _Pill(
                            icon: LucideIcons.badgeCheck,
                            label: 'No prescription needed',
                            color: AppColors.success,
                          ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: category.accent.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: MedicineImage(
                        drug: drug,
                        size: imageSize,
                        radius: 26,
                      ),
                    ),
                  ),
                ),
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
                  style: theme.bodySmall,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: stock.when(
                        loading: () => const Align(
                          alignment: Alignment.centerLeft,
                          child: Skeleton(width: 130, height: 14),
                        ),
                        error: (_, _) => Text(
                          'Availability unavailable',
                          style: theme.bodySmall,
                        ),
                        data: (items) {
                          if (items.isEmpty) {
                            return Text(
                              'Not in stock nearby right now',
                              style: theme.bodyMedium?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                          final cheapest = items
                              .map((i) => i.price)
                              .reduce((a, b) => a < b ? a : b);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'From ${formatKes(cheapest)}',
                                style: theme.titleMedium?.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '${items.length} chemist${items.length == 1 ? '' : 's'} have it',
                                style: theme.bodySmall,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      onPressed: () =>
                          context.push('/patient/chemist-select/${drug.id}'),
                      icon: const Icon(LucideIcons.store, size: 18),
                      label: const Text('Find chemists'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
  });

  final List<(MedicineCategory, List<Drug>)> shelves;
  final String selectedId;
  final ValueChanged<Drug> onSelect;

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
                        color: category.soft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        category.icon,
                        size: 16,
                        color: category.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(category.label, style: theme.titleMedium),
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
                  itemBuilder: (context, j) => _Thumb(
                    drug: drugs[j],
                    selected: drugs[j].id == selectedId,
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
  });

  final List<Drug> results;
  final String selectedId;
  final ValueChanged<Drug> onSelect;

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
            _Thumb(
              drug: d,
              selected: d.id == selectedId,
              onTap: () => onSelect(d),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.drug,
    required this.selected,
    required this.onTap,
  });

  final Drug drug;
  final bool selected;
  final VoidCallback onTap;

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
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            LucideIcons.fileText,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
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

class _GallerySkeleton extends StatelessWidget {
  const _GallerySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 280, radius: 28),
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
