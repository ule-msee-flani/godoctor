import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/my_doctor.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../../../services/live_updates.dart';
import '../widgets/doctor_widgets.dart';

/// Doctors I've seen and doctors I saved (saved first).
final myDoctorsProvider = FutureProvider.autoDispose<List<MyDoctor>>((ref) {
  ref.watch(liveTick(LiveTable.consultations));
  if (ref.watch(currentUserIdProvider) == null) return const [];
  return ref.watch(doctorDirectoryRepositoryProvider).myDoctors();
});

/// Doctors tab: "My doctors" — book again with doctors you know. Hidden
/// until there's one.
class MyDoctorsRow extends ConsumerWidget {
  const MyDoctorsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(myDoctorsProvider).valueOrNull ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My doctors',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          'Book again with doctors you know',
          style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 164,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _MyDoctorCard(item: list[i]),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MyDoctorCard extends StatelessWidget {
  const _MyDoctorCard({required this.item});

  final MyDoctor item;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = item.doctor;
    final seen = item.visits == 0
        ? 'Saved'
        : 'Seen ${item.visits == 1 ? 'once' : '${item.visits} times'}'
              '${item.lastVisit == null ? '' : ' · ${DateFormat('d MMM').format(item.lastVisit!)}'}';
    return SizedBox(
      width: 236,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/patient/doctor/${d.userId}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DoctorAvatar(
                      name: d.name,
                      avatarPath: d.avatarPath,
                      radius: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall,
                          ),
                          Text(
                            d.primarySpecialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.favorite)
                      const Icon(
                        Icons.favorite_rounded,
                        size: 18,
                        color: AppColors.danger,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  seen,
                  style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => context.push(
                      d.availableNow
                          ? '/patient/doctor/${d.userId}'
                          : '/patient/book/${d.userId}',
                    ),
                    child: Text(d.availableNow ? 'See now' : 'Book again'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Heart to save a doctor to "My doctors".
class FavoriteDoctorButton extends ConsumerStatefulWidget {
  const FavoriteDoctorButton({super.key, required this.doctorId});

  final String doctorId;

  @override
  ConsumerState<FavoriteDoctorButton> createState() =>
      _FavoriteDoctorButtonState();
}

class _FavoriteDoctorButtonState extends ConsumerState<FavoriteDoctorButton> {
  bool? _optimistic;

  @override
  Widget build(BuildContext context) {
    final saved =
        _optimistic ??
        (ref.watch(myDoctorsProvider).valueOrNull ?? const []).any(
          (d) => d.doctor.userId == widget.doctorId && d.favorite,
        );
    return IconButton.filled(
      tooltip: saved ? 'Remove from My doctors' : 'Save to My doctors',
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.92),
        foregroundColor: saved ? AppColors.danger : AppColors.ink,
      ),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
      ),
      onPressed: () async {
        HapticFeedback.lightImpact();
        final next = !saved;
        setState(() => _optimistic = next);
        final messenger = ScaffoldMessenger.of(context);
        try {
          await ref
              .read(doctorDirectoryRepositoryProvider)
              .setFavorite(widget.doctorId, next);
          ref.invalidate(myDoctorsProvider);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                next ? 'Saved to My doctors' : 'Removed from My doctors',
              ),
            ),
          );
        } catch (e) {
          if (mounted) setState(() => _optimistic = !next);
          messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      },
    );
  }
}
