import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/chemist_matching.dart';
import '../../location/match_location_bar.dart';
import '../../../services/live_updates.dart';

final _stockForDrugProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, drugId) =>
          ref.watch(drugRepositoryProvider).findStockForDrug(drugId),
    );

/// Chemists that have the medicine, most convenient first (near the
/// patient, then price). Where "near" is measured from is picked
/// automatically; the patient can search another place.
class ChemistSelectScreen extends ConsumerStatefulWidget {
  const ChemistSelectScreen({super.key, required this.drugId});

  final String drugId;

  @override
  ConsumerState<ChemistSelectScreen> createState() =>
      _ChemistSelectScreenState();
}

class _ChemistSelectScreenState extends ConsumerState<ChemistSelectScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) offerPreciseLocation(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final stockAsync = ref.watch(_stockForDrugProvider(widget.drugId));
    final at = ref.watch(matchingLocationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a chemist')),
      body: SafeArea(
        child: stockAsync.when(
          loading: () => const SkeletonList(),
          error: (e, _) => ErrorView(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(_stockForDrugProvider(widget.drugId)),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const EmptyView(
                message:
                    'No chemist on GoDoctor has this in stock right now. '
                    'Please check again later.',
                icon: LucideIcons.package,
              );
            }
            final ranked = rankByConvenience(items, at);
            final near = ranked.where((r) => r.km != null && r.km! <= 5);
            final far = ranked.where((r) => r.km == null || r.km! > 5);
            final requiresRx = items.first.drug?.requiresPrescription ?? false;
            var i = 0;

            Widget card(RankedStock r, {bool best = false}) => FadeSlideIn(
              index: i++,
              child: _ChemistCard(entry: r, best: best),
            );

            return LiveRefresh(
              onRefresh: () =>
                  ref.refresh(_stockForDrugProvider(widget.drugId).future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  const MatchLocationBar(),
                  const SizedBox(height: 14),
                  if (requiresRx)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            LucideIcons.fileText,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This medicine needs a prescription. You\'ll attach it at checkout.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (near.isNotEmpty) ...[
                    Text('Near you', style: theme.titleMedium),
                    const SizedBox(height: 8),
                    for (final (n, r) in near.indexed) card(r, best: n == 0),
                    if (far.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Further away', style: theme.titleMedium),
                      const SizedBox(height: 8),
                    ],
                  ],
                  for (final (n, r) in far.indexed)
                    card(r, best: near.isEmpty && n == 0 && r.km != null),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChemistCard extends StatelessWidget {
  const _ChemistCard({required this.entry, this.best = false});

  final RankedStock entry;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        child: Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: best ? AppColors.primary : AppColors.border,
              width: best ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/patient/checkout', extra: entry.item),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // This chemist's own pack photo if they uploaded one,
                  // otherwise a shop icon.
                  _ChemistPackThumb(path: entry.item.imagePath),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (best)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Best match',
                                style: theme.labelSmall?.copyWith(
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                        Text(
                          entry.item.chemistName ?? 'Chemist',
                          style: theme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            _MetaChip(
                              icon: LucideIcons.wallet,
                              text: formatKes(entry.item.price),
                            ),
                            _MetaChip(
                              icon: LucideIcons.package,
                              text: '${entry.item.quantity} in stock',
                            ),
                            if (entry.km != null)
                              _MetaChip(
                                icon: LucideIcons.mapPin,
                                text: distanceLabel(entry.km!),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Who they'd be buying from.
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context.push(
                            '/patient/chemist/${entry.item.chemistId}',
                            extra: entry.item,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.store,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Pharmacy profile',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.labelLarge?.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
