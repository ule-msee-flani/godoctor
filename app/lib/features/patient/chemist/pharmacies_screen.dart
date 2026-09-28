import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_chemist.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/chemist_matching.dart';
import '../../../services/distance.dart';
import '../../../services/live_updates.dart';
import '../../location/match_location_bar.dart';

/// Every verified pharmacy.
final publicChemistsProvider = FutureProvider.autoDispose<List<PublicChemist>>(
  (ref) => ref.watch(doctorDirectoryRepositoryProvider).listChemists(),
);

typedef RankedPharmacy = ({PublicChemist chemist, double? km});

/// Nearest first; pharmacies without a location go last, busiest first.
/// [query] matches the name or area. Pure, for tests.
List<RankedPharmacy> rankPharmacies(
  List<PublicChemist> all,
  MatchPoint? at, {
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final ranked = [
    for (final c in all)
      if (q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          (c.locationName ?? '').toLowerCase().contains(q))
        (
          chemist: c,
          km: at == null || !c.hasLocation
              ? null
              : distanceKm(at.lat, at.lng, c.lat!, c.lng!),
        ),
  ];
  ranked.sort((a, b) {
    if (a.km != null && b.km != null) return a.km!.compareTo(b.km!);
    if (a.km != null) return -1;
    if (b.km != null) return 1;
    return b.chemist.ordersFilled.compareTo(a.chemist.ordersFilled);
  });
  return ranked;
}

/// Pharmacies near the patient, to browse like doctors: a tap opens the
/// pharmacy's profile (photo, location, what's in stock).
class PharmaciesScreen extends ConsumerStatefulWidget {
  const PharmaciesScreen({super.key});

  @override
  ConsumerState<PharmaciesScreen> createState() => _PharmaciesScreenState();
}

class _PharmaciesScreenState extends ConsumerState<PharmaciesScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) offerPreciseLocation(context, ref);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicChemistsProvider);
    final at = ref.watch(matchingLocationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pharmacies')),
      body: LiveRefresh(
        onRefresh: () => ref.refresh(publicChemistsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const MatchLocationBar(),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by name or area',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
            const SizedBox(height: 14),
            ...async.when(
              skipLoadingOnRefresh: true,
              loading: () => const [
                SizedBox(
                  height: 400,
                  child: SkeletonList(itemCount: 5, padding: EdgeInsets.zero),
                ),
              ],
              error: (e, _) => [
                ErrorView(
                  message: friendlyError(e),
                  onRetry: () => ref.invalidate(publicChemistsProvider),
                ),
              ],
              data: (all) {
                final ranked = rankPharmacies(all, at, query: _search.text);
                if (ranked.isEmpty) {
                  return [
                    EmptyView(
                      message: all.isEmpty
                          ? 'No pharmacies yet.'
                          : 'No pharmacy matches "${_search.text.trim()}".',
                      icon: LucideIcons.store,
                    ),
                  ];
                }
                return [
                  for (var i = 0; i < ranked.length; i++)
                    FadeSlideIn(
                      index: i,
                      child: PharmacyCard(
                        chemist: ranked[i].chemist,
                        km: ranked[i].km,
                        nearest: i == 0 && ranked[i].km != null,
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}

class PharmacyCard extends ConsumerWidget {
  const PharmacyCard({
    super.key,
    required this.chemist,
    this.km,
    this.nearest = false,
  });

  final PublicChemist chemist;
  final double? km;
  final bool nearest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final c = chemist;
    final photo = ref.watch(profileRepositoryProvider).avatarUrl(c.avatarPath);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        child: Material(
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: nearest ? AppColors.primary : AppColors.border,
              width: nearest ? 1.4 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/patient/chemist/${c.userId}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 72,
                      height: 72,
                      color: AppColors.primarySoft,
                      child: photo == null
                          ? const Icon(
                              LucideIcons.store,
                              color: AppColors.primary,
                              size: 28,
                            )
                          : Image.network(
                              photo,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                LucideIcons.store,
                                color: AppColors.primary,
                                size: 28,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (nearest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'NEAREST',
                              style: text.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.badgeCheck,
                              size: 15,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                        if ((c.locationName ?? '').trim().isNotEmpty)
                          Text(
                            c.locationName!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 2,
                          children: [
                            if (km != null)
                              _Meta(
                                icon: LucideIcons.mapPin,
                                text: distanceLabel(km!),
                              ),
                            _Meta(
                              icon: LucideIcons.pill,
                              text: c.medicinesInStock == 1
                                  ? '1 medicine'
                                  : '${c.medicinesInStock} medicines',
                            ),
                            if (c.ordersFilled > 0)
                              _Meta(
                                icon: LucideIcons.packageCheck,
                                text: '${c.ordersFilled} orders filled',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: AppColors.inkFaint,
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.inkFaint),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.inkSoft),
        ),
      ],
    );
  }
}

/// "Browse pharmacies near you" — the way into [PharmaciesScreen].
class PharmaciesBanner extends StatelessWidget {
  const PharmaciesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.primarySofter,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/patient/pharmacies'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.store,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pharmacies near you', style: text.titleSmall),
                    Text(
                      'See their photos, location and what they stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: AppColors.inkFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
