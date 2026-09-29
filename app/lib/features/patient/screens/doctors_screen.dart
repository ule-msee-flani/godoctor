import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/doctor_widgets.dart';
import '../widgets/specialty_tiles.dart';
import '../../../services/live_updates.dart';
import '../doctors/my_doctors.dart';

const _unset = Object();

/// Directory search filters. `null` means "any".
class DoctorFilters {
  const DoctorFilters({
    this.query = '',
    this.specialty,
    this.maxFee,
    this.language,
    this.gender,
    this.availableNow = false,
  });

  final String query;
  final String? specialty;
  final double? maxFee;
  final String? language;
  final String? gender;
  final bool availableNow;

  /// Filters beyond the search text and specialty chips (shown as a badge on
  /// the filter button).
  int get advancedCount =>
      (maxFee != null ? 1 : 0) +
      (language != null ? 1 : 0) +
      (gender != null ? 1 : 0);

  bool get isDefault =>
      query.isEmpty && specialty == null && advancedCount == 0 && !availableNow;

  DoctorFilters copyWith({
    String? query,
    Object? specialty = _unset,
    Object? maxFee = _unset,
    Object? language = _unset,
    Object? gender = _unset,
    bool? availableNow,
  }) => DoctorFilters(
    query: query ?? this.query,
    specialty: identical(specialty, _unset)
        ? this.specialty
        : specialty as String?,
    maxFee: identical(maxFee, _unset) ? this.maxFee : maxFee as double?,
    language: identical(language, _unset) ? this.language : language as String?,
    gender: identical(gender, _unset) ? this.gender : gender as String?,
    availableNow: availableNow ?? this.availableNow,
  );
}

final doctorFiltersProvider = StateProvider.autoDispose<DoctorFilters>(
  (ref) => const DoctorFilters(),
);

final doctorSearchProvider = FutureProvider.autoDispose<List<PublicDoctor>>((
  ref,
) {
  final f = ref.watch(doctorFiltersProvider);
  return ref
      .watch(doctorDirectoryRepositoryProvider)
      .search(
        query: f.query,
        specialty: f.specialty,
        maxFee: f.maxFee,
        language: f.language,
        gender: f.gender,
        availableNow: f.availableNow,
        limit: 50,
      );
});

/// Open slots per day for the doctors in view (ids joined with commas).
final _slotCountsProvider = FutureProvider.autoDispose
    .family<Map<String, Map<DateTime, int>>, String>(
      (ref, ids) => ids.isEmpty
          ? const {}
          : ref
                .watch(doctorDirectoryRepositoryProvider)
                .slotCounts(ids.split(','), days: 4),
    );

class DoctorsScreen extends ConsumerStatefulWidget {
  const DoctorsScreen({super.key, this.initialSpecialty});

  /// Applied as the specialty filter when the screen opens or the link
  /// changes (e.g. from a specialty page's "Find ENT doctors" button).
  final String? initialSpecialty;

  @override
  ConsumerState<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends ConsumerState<DoctorsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _applyInitialSpecialty();
  }

  @override
  void didUpdateWidget(covariant DoctorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSpecialty != oldWidget.initialSpecialty) {
      _applyInitialSpecialty();
    }
  }

  void _applyInitialSpecialty() {
    final specialty = widget.initialSpecialty;
    if (specialty == null || specialty.isEmpty) return;
    // Providers can't be modified while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(doctorFiltersProvider.notifier)
          .update((f) => f.copyWith(specialty: specialty));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(doctorFiltersProvider.notifier)
          .update((f) => f.copyWith(query: value.trim()));
    });
  }

  Future<void> _openFilters() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FilterSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(doctorFiltersProvider);
    final results = ref.watch(doctorSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a doctor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search by name or specialty',
                      prefixIcon: Icon(LucideIcons.search, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Badge(
                  isLabelVisible: filters.advancedCount > 0,
                  label: Text('${filters.advancedCount}'),
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.white,
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.4,
                      ),
                      fixedSize: const Size(56, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    tooltip: 'Filters',
                    icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
                    onPressed: _openFilters,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  avatar: const Icon(LucideIcons.zap, size: 14),
                  label: const Text('Available now'),
                  selected: filters.availableNow,
                  onSelected: (v) => ref
                      .read(doctorFiltersProvider.notifier)
                      .update((f) => f.copyWith(availableNow: v)),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('All'),
                  selected: filters.specialty == null,
                  onSelected: (_) => ref
                      .read(doctorFiltersProvider.notifier)
                      .update((f) => f.copyWith(specialty: null)),
                ),
                for (final meta in kSpecialtyMeta) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(meta.label),
                    selected: filters.specialty == meta.name,
                    onSelected: (sel) => ref
                        .read(doctorFiltersProvider.notifier)
                        .update(
                          (f) => f.copyWith(specialty: sel ? meta.name : null),
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: results.when(
              loading: () => const SkeletonList(itemCount: 5),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(doctorSearchProvider),
              ),
              data: (doctors) {
                if (doctors.isEmpty) {
                  return EmptyView(
                    message: filters.isDefault
                        ? 'No certified doctors have joined yet. Please check back soon.'
                        : 'No doctors match those filters.',
                    icon: LucideIcons.stethoscope,
                    action: filters.isDefault
                        ? null
                        : OutlinedButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              ref.read(doctorFiltersProvider.notifier).state =
                                  const DoctorFilters();
                            },
                            child: const Text('Clear filters'),
                          ),
                  );
                }
                final slots = ref
                    .watch(
                      _slotCountsProvider(
                        doctors.take(50).map((d) => d.userId).join(','),
                      ),
                    )
                    .valueOrNull;
                return LiveRefresh(
                  onRefresh: () async {
                    ref.invalidate(myDoctorsProvider);
                    return ref.refresh(doctorSearchProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: doctors.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (filters.isDefault) const MyDoctorsRow(),
                              Row(
                                children: [
                                  const VerifiedBadge(size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${doctors.length} licence-verified '
                                    '${doctors.length == 1 ? 'doctor' : 'doctors'}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }
                      final d = doctors[i - 1];
                      return DoctorCard(
                        doctor: d,
                        slots: slots == null
                            ? null
                            : (slots[d.userId] ?? const {}),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  static const _fees = <double?>[null, 500, 1000, 2000, 5000];
  static const _genders = <(String?, String)>[
    (null, 'Any'),
    ('female', 'Female'),
    ('male', 'Male'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(doctorFiltersProvider);
    final notifier = ref.read(doctorFiltersProvider.notifier);
    final theme = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filters', style: theme.titleLarge)),
                TextButton(
                  onPressed: () => notifier.update(
                    (f) =>
                        f.copyWith(maxFee: null, language: null, gender: null),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Maximum fee', style: theme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final fee in _fees)
                  ChoiceChip(
                    label: Text(
                      fee == null ? 'Any' : 'Up to ${formatKes(fee)}',
                    ),
                    selected: filters.maxFee == fee,
                    onSelected: (_) =>
                        notifier.update((f) => f.copyWith(maxFee: fee)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Language spoken', style: theme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any'),
                  selected: filters.language == null,
                  onSelected: (_) =>
                      notifier.update((f) => f.copyWith(language: null)),
                ),
                for (final lang in kDoctorLanguages)
                  ChoiceChip(
                    label: Text(lang),
                    selected: filters.language == lang,
                    onSelected: (_) =>
                        notifier.update((f) => f.copyWith(language: lang)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Doctor\'s gender', style: theme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final (value, label) in _genders)
                  ChoiceChip(
                    label: Text(label),
                    selected: filters.gender == value,
                    onSelected: (_) =>
                        notifier.update((f) => f.copyWith(gender: value)),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Show doctors'),
            ),
          ],
        ),
      ),
    );
  }
}
