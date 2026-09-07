import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../services/distance.dart';

final _stockForDrugProvider = FutureProvider.family<
  List<ChemistInventoryItem>,
  String
>((ref, drugId) => ref.watch(drugRepositoryProvider).findStockForDrug(drugId));

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
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(message: '$e'),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(
                message: 'No chemists currently have this in stock nearby.',
                icon: Icons.inventory_2_outlined,
              );
            }

            final withDistance = items.map((item) {
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
              if (a.km == null && b.km == null) return a.item.price.compareTo(b.item.price);
              if (a.km == null) return 1;
              if (b.km == null) return -1;
              return a.km!.compareTo(b.km!);
            });

            final requiresRx = items.first.drug?.requiresPrescription ?? false;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (requiresRx)
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This medicine requires a valid prescription to order.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                ...withDistance.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.local_pharmacy_outlined),
                      ),
                      title: Text(entry.item.chemistName ?? 'Chemist'),
                      subtitle: Text(
                        [
                          'KES ${entry.item.price.toStringAsFixed(0)}',
                          '${entry.item.quantity} in stock',
                          if (entry.km != null) '${entry.km!.toStringAsFixed(1)} km away',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '/patient/checkout',
                        extra: entry.item,
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
