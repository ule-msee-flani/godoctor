import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/skeleton.dart';
import '../../data/models/prescription.dart';
import '../../data/providers/auth_providers.dart';
import 'chemist_match.dart';

/// Under an issued prescription: the chemist that best fills it (most
/// medicines in stock, then nearest, then cheapest) with an "Order" button,
/// plus a link to compare other chemists.
class SuggestedChemistCard extends ConsumerWidget {
  const SuggestedChemistCard({super.key, required this.prescription});

  final Prescription prescription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final key = stockKeyFor(prescription);
    final orderRoute = '/patient/prescription/${prescription.id}/order';

    if (key.isEmpty) {
      // Only free-text medicines: nothing to match automatically.
      return _Shell(
        child: Row(
          children: [
            const Icon(LucideIcons.store, size: 18, color: AppColors.inkFaint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Show this prescription at any chemist to get your medicines.',
                style: theme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final stock = ref.watch(prescriptionStockProvider(key));
    final patient = ref.watch(currentPatientProfileProvider).valueOrNull;

    return _Shell(
      child: stock.when(
        loading: () => const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 160, height: 14),
            SizedBox(height: 8),
            Skeleton(height: 44),
          ],
        ),
        error: (_, _) => Text(
          'Could not check which chemists have these medicines.',
          style: theme.bodyMedium,
        ),
        data: (items) {
          final ranked = rankChemists(
            prescription,
            items,
            patientLat: patient?.locationLat,
            patientLng: patient?.locationLng,
          );
          if (ranked.isEmpty) {
            return Row(
              children: [
                const Icon(
                  LucideIcons.packageX,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No chemist on GoDoctor has these in stock right now. '
                    'You can still show this prescription at any chemist.',
                    style: theme.bodyMedium,
                  ),
                ),
              ],
            );
          }
          final best = ranked.first;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.sparkles,
                    size: 16,
                    color: AppColors.ink,
                  ),
                  const SizedBox(width: 6),
                  Text('Suggested chemist', style: theme.labelLarge),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.store,
                      color: AppColors.ink,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(best.chemistName, style: theme.titleSmall),
                        Text(
                          [
                            best.hasEverything
                                ? 'Has all ${best.wanted}'
                                : 'Has ${best.lines.length} of ${best.wanted}',
                            if (best.km != null)
                              '${best.km!.toStringAsFixed(1)} km',
                          ].join(' · '),
                          style: theme.bodySmall?.copyWith(
                            color: best.hasEverything
                                ? AppColors.success
                                : AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(formatKes(best.total), style: theme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () =>
                    context.push('$orderRoute?chemist=${best.chemistId}'),
                icon: const Icon(LucideIcons.shoppingBag, size: 18),
                label: Text('Order from ${best.chemistName}'),
              ),
              if (ranked.length > 1)
                TextButton(
                  onPressed: () => context.push(orderRoute),
                  child: Text(
                    'Compare ${ranked.length - 1} other chemist${ranked.length == 2 ? '' : 's'}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
