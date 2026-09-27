import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/distance.dart';
import '../../../data/repositories/repository_errors.dart';

final _stockForDrugProvider =
    FutureProvider.family<List<ChemistInventoryItem>, String>(
      (ref, drugId) =>
          ref.watch(drugRepositoryProvider).findStockForDrug(drugId),
    );

class ChemistSelectScreen extends ConsumerWidget {
  const ChemistSelectScreen({super.key, required this.drugId});

  final String drugId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(_stockForDrugProvider(drugId));
    final patientProfile = ref.watch(currentPatientProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a chemist')),
      body: SafeArea(
        child: stockAsync.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorView(message: friendlyError(e)),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(
                message: 'No chemists currently have this in stock nearby.',
                icon: LucideIcons.package,
              );
            }

            final withDistance =
                items.map((item) {
                  double? km;
                  if (patientProfile?.locationLat != null &&
                      patientProfile?.locationLng != null &&
                      item.chemistLat != null &&
                      item.chemistLng != null) {
                    km = distanceKm(
                      patientProfile!.locationLat!,
                      patientProfile.locationLng!,
                      item.chemistLat!,
                      item.chemistLng!,
                    );
                  }
                  return (item: item, km: km);
                }).toList()..sort((a, b) {
                  if (a.km == null && b.km == null) {
                    return a.item.price.compareTo(b.item.price);
                  }
                  if (a.km == null) return 1;
                  if (b.km == null) return -1;
                  return a.km!.compareTo(b.km!);
                });

            final requiresRx = items.first.drug?.requiresPrescription ?? false;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (requiresRx)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          LucideIcons.info,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This medicine requires a valid prescription to order.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ...withDistance.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => context.push(
                          '/patient/checkout',
                          extra: entry.item,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              // This chemist's own pack photo if they
                              // uploaded one, otherwise a shop icon.
                              _ChemistPackThumb(path: entry.item.imagePath),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.item.chemistName ?? 'Chemist',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 2,
                                      children: [
                                        _MetaChip(
                                          icon: LucideIcons.wallet,
                                          text:
                                              'KES ${entry.item.price.toStringAsFixed(0)}',
                                        ),
                                        _MetaChip(
                                          icon: LucideIcons.package,
                                          text:
                                              '${entry.item.quantity} in stock',
                                        ),
                                        if (entry.km != null)
                                          _MetaChip(
                                            icon: LucideIcons.mapPin,
                                            text:
                                                '${entry.km!.toStringAsFixed(1)} km',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                LucideIcons.chevronRight,
                                color: AppColors.inkFaint,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkFaint),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ChemistPackThumb extends ConsumerWidget {
  const _ChemistPackThumb({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(drugRepositoryProvider).inventoryPhotoUrl(path);
    Widget shop() => Container(
      color: const Color(0xFFF3F4F7),
      child: const Center(
        child: Icon(LucideIcons.store, color: AppColors.ink, size: 22),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null
            ? shop()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => shop(),
              ),
      ),
    );
  }
}
