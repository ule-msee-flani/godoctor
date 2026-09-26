import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../medicine/medicine_gallery.dart';

final _availabilityProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, drugId) =>
          ref.watch(drugRepositoryProvider).findStockForDrug(drugId),
    );

/// Doctor's "Medicines" tab: the same gallery patients use, for looking up
/// a medicine and seeing whether chemists on GoDoctor have it before
/// prescribing. Prescribing itself happens on the consultation screen.
class DoctorMedicinesScreen extends ConsumerStatefulWidget {
  const DoctorMedicinesScreen({super.key});

  @override
  ConsumerState<DoctorMedicinesScreen> createState() =>
      _DoctorMedicinesScreenState();
}

class _DoctorMedicinesScreenState extends ConsumerState<DoctorMedicinesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(medicineCatalogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Medicines')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: MedicineSearchField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: catalog.when(
              loading: () => const MedicineGallerySkeleton(),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(medicineCatalogProvider),
              ),
              data: (drugs) => MedicineGallery(
                drugs: drugs,
                query: _searchCtrl.text,
                emptyMessage: 'The medicine catalogue is empty.',
                footerBuilder: (context, drug) => _Availability(drug: drug),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Availability extends ConsumerWidget {
  const _Availability({required this.drug});

  final Drug drug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final stock = ref.watch(_availabilityProvider(drug.id));
    return Row(
      children: [
        const Icon(LucideIcons.store, size: 18, color: AppColors.inkFaint),
        const SizedBox(width: 10),
        Expanded(
          child: stock.when(
            loading: () => const Align(
              alignment: Alignment.centerLeft,
              child: Skeleton(width: 160, height: 14),
            ),
            error: (_, _) =>
                Text('Availability unavailable', style: theme.bodySmall),
            data: (items) {
              if (items.isEmpty) {
                return Text(
                  'No chemist on GoDoctor stocks this yet',
                  style: theme.bodyMedium?.copyWith(color: AppColors.warning),
                );
              }
              final cheapest = items
                  .map((i) => i.price)
                  .reduce((a, b) => a < b ? a : b);
              return Text(
                'In stock at ${items.length} chemist${items.length == 1 ? '' : 's'} · from ${formatKes(cheapest)}',
                style: theme.bodyMedium?.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
