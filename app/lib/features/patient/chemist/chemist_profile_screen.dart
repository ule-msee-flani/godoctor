import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/profile_hero.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/drug.dart';
import '../../../data/models/public_chemist.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/chemist_matching.dart';
import '../../../services/distance.dart';
import '../../location/location_picker_screen.dart'
    show mapTilesEnabledProvider;
import '../widgets/doctor_widgets.dart' show VerifiedBadge;
import '../widgets/medicine_image.dart';
import '../../../data/models/public_doctor.dart' show DoctorReview;
import '../../reviews/review_widgets.dart';

final publicChemistProvider = FutureProvider.autoDispose
    .family<PublicChemist?, String>(
      (ref, id) => ref.watch(doctorDirectoryRepositoryProvider).getChemist(id),
    );

/// What patients said about a pharmacy.
final chemistReviewsProvider = FutureProvider.autoDispose
    .family<List<DoctorReview>, String>(
      (ref, id) =>
          ref.watch(doctorDirectoryRepositoryProvider).chemistReviews(id),
    );

final chemistStockProvider = FutureProvider.autoDispose
    .family<List<ChemistInventoryItem>, String>(
      (ref, id) => ref.watch(drugRepositoryProvider).publicStock(id),
    );

/// A pharmacy's page, so the patient knows exactly who they're buying from:
/// its photo, where it is, how many orders it has filled, and what it has
/// in stock. [item] (the medicine being bought) adds a "Buy here" button.
class ChemistProfileScreen extends ConsumerWidget {
  const ChemistProfileScreen({super.key, required this.chemistId, this.item});

  final String chemistId;
  final ChemistInventoryItem? item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicChemistProvider(chemistId));
    return async.when(
      loading: () =>
          Scaffold(appBar: AppBar(), body: const SkeletonList(itemCount: 3)),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(publicChemistProvider(chemistId)),
        ),
      ),
      data: (c) {
        if (c == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              message: 'This pharmacy isn\'t on GoDoctor right now.',
              icon: LucideIcons.store,
            ),
          );
        }
        return ProfileHeroScaffold(
          title: c.name,
          photoUrl: ref
              .watch(profileRepositoryProvider)
              .avatarUrl(c.avatarPath),
          fallbackIcon: LucideIcons.store,
          bottomBar: item == null ? null : _BuyBar(item: item!),
          children: _page(context, ref, c),
        );
      },
    );
  }

  List<Widget> _page(BuildContext context, WidgetRef ref, PublicChemist c) {
    final theme = Theme.of(context).textTheme;
    final at = ref.watch(matchingLocationProvider);
    final km = at == null || !c.hasLocation
        ? null
        : distanceKm(at.lat, at.lng, c.lat!, c.lng!);
    final stock = ref.watch(chemistStockProvider(chemistId));

    return [
      FadeSlideIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    c.name,
                    style: theme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const VerifiedBadge(size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  LucideIcons.mapPin,
                  size: 15,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    [
                      c.locationName ?? 'Location not added yet',
                      if (km != null) '${distanceLabel(km)} away',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Pharmacy registration verified by GoDoctor',
                      style: theme.labelMedium?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      FadeSlideIn(
        index: 1,
        child: ProfileStatsRow(
          stats: [
            ProfileStat(
              value: c.ratingCount == 0
                  ? 'New'
                  : '${c.ratingAvg.toStringAsFixed(1)} ★',
              label: c.ratingCount == 0
                  ? 'No reviews yet'
                  : c.ratingCount == 1
                  ? '1 review'
                  : '${c.ratingCount} reviews',
            ),
            ProfileStat(value: '${c.ordersFilled}', label: 'Orders filled'),
            ProfileStat(value: '${c.medicinesInStock}', label: 'Medicines'),
          ],
        ),
      ),
      if (c.hasLocation)
        ProfileSection(
          title: 'Where to find them',
          child: _MapCard(chemist: c),
        ),
      if (c.contactPhone != null && c.contactPhone!.trim().isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: OutlinedButton.icon(
            onPressed: () =>
                launchUrl(Uri(scheme: 'tel', path: c.contactPhone!.trim())),
            icon: const Icon(LucideIcons.phone, size: 18),
            label: Text('Call ${c.name}'),
          ),
        ),
      ProfileSection(
        title: 'In stock',
        child: stock.when(
          loading: () => const SizedBox(
            height: 160,
            child: SkeletonList(itemCount: 2, padding: EdgeInsets.zero),
          ),
          error: (e, _) => Text(friendlyError(e)),
          data: (list) {
            if (list.isEmpty) {
              return Text('Nothing listed right now.', style: theme.bodyMedium);
            }
            return Column(
              children: [
                for (final (i, s) in list.indexed)
                  FadeSlideIn(
                    index: i,
                    child: _StockRow(item: s),
                  ),
              ],
            );
          },
        ),
      ),
      ProfileSection(
        title: 'What patients say',
        child: ReviewsBlock(
          reviews: ref.watch(chemistReviewsProvider(chemistId)),
          average: c.ratingAvg,
          count: c.ratingCount,
          breakdown: ref.watch(ratingBreakdownProvider(chemistId)).valueOrNull,
          emptyText:
              'No reviews yet. Patients can rate a pharmacy after an order.',
        ),
      ),
      if (c.memberSince != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'On GoDoctor since ${c.memberSince!.year}',
            textAlign: TextAlign.center,
            style: theme.bodySmall?.copyWith(color: AppColors.inkFaint),
          ),
        ),
    ];
  }
}

class _MapCard extends ConsumerWidget {
  const _MapCard({required this.chemist});

  final PublicChemist chemist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = LatLng(chemist.lat!, chemist.lng!);
    final tiles = ref.watch(mapTilesEnabledProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 170,
              child: tiles
                  ? FlutterMap(
                      options: MapOptions(
                        initialCenter: point,
                        initialZoom: 15,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.godoctor.godoctor_app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: point,
                              width: 40,
                              height: 40,
                              alignment: Alignment.topCenter,
                              child: const Icon(
                                LucideIcons.mapPin,
                                size: 36,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                        const SimpleAttributionWidget(
                          source: Text('OpenStreetMap contributors'),
                        ),
                      ],
                    )
                  : const ColoredBox(
                      color: AppColors.primarySofter,
                      child: Center(
                        child: Icon(
                          LucideIcons.mapPin,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
            ),
            Material(
              color: AppColors.white,
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${chemist.lat},${chemist.lng}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.navigation,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Get directions',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(color: AppColors.primary),
                        ),
                      ),
                      const Icon(
                        LucideIcons.externalLink,
                        size: 16,
                        color: AppColors.inkFaint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.item});

  final ChemistInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final drug = item.drug;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (drug != null)
            MedicineImage(drug: drug, size: 48, radius: 12)
          else
            const SizedBox(width: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drug?.displayName ?? 'Medicine',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
                Text(
                  '${formatKes(item.price)} · ${item.quantity} in stock'
                  '${drug?.requiresPrescription == true ? ' · needs prescription' : ''}',
                  style: theme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/patient/checkout', extra: item),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }
}

class _BuyBar extends StatelessWidget {
  const _BuyBar({required this.item});

  final ChemistInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.drug?.displayName ?? 'Medicine',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall,
                  ),
                  Text(formatKes(item.price), style: theme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => context.push('/patient/checkout', extra: item),
              icon: const Icon(LucideIcons.shoppingBag, size: 18),
              label: const Text('Buy here'),
            ),
          ],
        ),
      ),
    );
  }
}
