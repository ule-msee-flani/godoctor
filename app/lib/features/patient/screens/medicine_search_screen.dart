import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medicine/medicine_gallery.dart';
import '../chemist/pharmacies_screen.dart';

/// Stock at verified chemists for the medicine being showcased.
final _stockProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, drugId) =>
          ref.watch(drugRepositoryProvider).findStockForDrug(drugId),
    );

/// "Order medicine": the shared medicine gallery, with where-to-buy and a
/// "Find chemists" button under the featured medicine.
class MedicineSearchScreen extends ConsumerStatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  ConsumerState<MedicineSearchScreen> createState() =>
      _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends ConsumerState<MedicineSearchScreen> {
  bool _searching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _searchCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicineCatalogProvider);

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
        loading: () => const MedicineGallerySkeleton(),
        error: (e, _) => ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(medicineCatalogProvider),
        ),
        data: (drugs) => Column(
          children: [
            if (!_searching)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: PharmaciesBanner(),
              ),
            Expanded(
              child: MedicineGallery(
                drugs: drugs,
                query: _searching ? _searchCtrl.text : '',
                emptyMessage: 'The medicine catalogue is empty.',
                footerBuilder: (context, drug) => _WhereToBuy(drug: drug),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhereToBuy extends ConsumerWidget {
  const _WhereToBuy({required this.drug});

  final Drug drug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final stock = ref.watch(_stockProvider(drug.id));
    return Row(
      children: [
        Expanded(
          child: stock.when(
            loading: () => const Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 130, height: 14),
            ),
            error: (_, _) =>
                Text('Availability unavailable', style: theme.bodySmall),
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
          onPressed: () => context.push('/patient/chemist-select/${drug.id}'),
          icon: const Icon(LucideIcons.store, size: 18),
          label: const Text('Find chemists'),
        ),
      ],
    );
  }
}
