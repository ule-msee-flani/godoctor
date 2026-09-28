import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../data/models/public_doctor.dart';
import '../../../data/providers/repository_providers.dart';
import '../../../data/repositories/repository_errors.dart';
import '../widgets/doctor_widgets.dart';
import '../widgets/specialty_tiles.dart';
import 'consult_flow.dart';
import '../../../services/live_updates.dart';

/// Verified doctors who are online right now for [specialty].
final onlineDoctorsProvider = FutureProvider.autoDispose
    .family<List<PublicDoctor>, String>(
      (ref, specialty) => ref
          .watch(doctorDirectoryRepositoryProvider)
          .search(specialty: specialty, availableNow: true, limit: 50),
    );

/// "See a doctor", step 2 of 3: choose from the doctors who are online now.
/// Tapping a doctor opens their full profile and reviews, with a "See now"
/// button that takes the patient to payment.
class AvailableDoctorsScreen extends ConsumerStatefulWidget {
  const AvailableDoctorsScreen({super.key});

  @override
  ConsumerState<AvailableDoctorsScreen> createState() =>
      _AvailableDoctorsScreenState();
}

class _AvailableDoctorsScreenState
    extends ConsumerState<AvailableDoctorsScreen> {
  Timer? _refresh;

  /// Shows General doctors instead when nobody in the chosen specialty is on.
  bool _showingGeneral = false;

  @override
  void initState() {
    super.initState();
    // Doctors come and go: keep the list fresh while the patient is choosing.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      final draft = ref.read(consultDraftProvider);
      if (draft != null) {
        ref.invalidate(onlineDoctorsProvider(_specialty(draft)));
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  String _specialty(ConsultDraft draft) =>
      _showingGeneral ? 'General Practice' : draft.specialty;

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(consultDraftProvider);
    final theme = Theme.of(context).textTheme;

    if (draft == null) {
      // Opened directly (e.g. after the app restarted): start from step 1.
      return Scaffold(
        appBar: AppBar(title: const Text('Choose a doctor')),
        body: EmptyView(
          message: 'Tell us what\'s going on first.',
          icon: LucideIcons.notebookPen,
          action: FilledButton(
            onPressed: () => context.pushReplacement('/patient/intake'),
            child: const Text('Start'),
          ),
        ),
      );
    }

    final specialty = _specialty(draft);
    final meta = specialtyMetaFor(specialty);
    final doctors = ref.watch(onlineDoctorsProvider(specialty));

    return Scaffold(
      appBar: AppBar(title: const Text('Choose a doctor')),
      body: LiveRefresh(
        onRefresh: () => ref.refresh(onlineDoctorsProvider(specialty).future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            const ConsultSteps(current: 2),
            const SizedBox(height: 20),
            Row(
              children: [
                SpecialtyImage(meta: meta, size: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${meta.label} doctors online now',
                        style: theme.titleMedium,
                      ),
                      Text(
                        '"${draft.symptoms}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CameraPreference(
              doctorVideo: draft.doctorVideo,
              onChanged: (v) => ref.read(consultDraftProvider.notifier).state =
                  draft.copyWith(doctorVideo: v),
            ),
            const SizedBox(height: 16),
            doctors.when(
              loading: () => const SizedBox(
                height: 420,
                child: SkeletonList(itemCount: 4, padding: EdgeInsets.zero),
              ),
              error: (e, _) => ErrorView(
                message: friendlyError(e),
                onRetry: () => ref.invalidate(onlineDoctorsProvider(specialty)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return _NoneOnline(
                    specialtyLabel: meta.label,
                    canTryGeneral:
                        !_showingGeneral && specialty != 'General Practice',
                    onTryGeneral: () => setState(() => _showingGeneral = true),
                    onBookLater: () => context.go(
                      '/patient/doctors?specialty=${Uri.encodeQueryComponent(draft.specialty)}',
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Tap a doctor to see their profile and reviews.',
                      style: theme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    for (final d in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DoctorCard(
                          doctor: d,
                          onTap: () => context.push(
                            '/patient/doctor/${d.userId}?see=now',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NoneOnline extends StatelessWidget {
  const _NoneOnline({
    required this.specialtyLabel,
    required this.canTryGeneral,
    required this.onTryGeneral,
    required this.onBookLater,
  });

  final String specialtyLabel;
  final bool canTryGeneral;
  final VoidCallback onTryGeneral;
  final VoidCallback onBookLater;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            LucideIcons.userRoundX,
            size: 36,
            color: AppColors.inkFaint,
          ),
          const SizedBox(height: 12),
          Text(
            'No $specialtyLabel doctors are online right now',
            textAlign: TextAlign.center,
            style: theme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'This list updates by itself when a doctor comes online.',
            textAlign: TextAlign.center,
            style: theme.bodyMedium,
          ),
          const SizedBox(height: 18),
          if (canTryGeneral) ...[
            FilledButton.icon(
              onPressed: onTryGeneral,
              icon: const Icon(LucideIcons.stethoscope, size: 18),
              label: const Text('See a General doctor instead'),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton.icon(
            onPressed: onBookLater,
            icon: const Icon(LucideIcons.calendarPlus, size: 18),
            label: const Text('Book an appointment for later'),
          ),
        ],
      ),
    );
  }
}

/// "Doctor's camera: On / Off". Every consultation is a video consultation
/// at the same price; turning the doctor's camera off saves the patient's
/// data. The patient can also switch their own camera during the call.
class _CameraPreference extends StatelessWidget {
  const _CameraPreference({required this.doctorVideo, required this.onChanged});

  final bool doctorVideo;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.video, size: 18, color: AppColors.ink),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Doctor\x27s camera', style: theme.titleSmall),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: true, label: Text('On')),
                  ButtonSegment(value: false, label: Text('Off')),
                ],
                selected: {doctorVideo},
                onSelectionChanged: (s) => onChanged(s.first),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            doctorVideo
                ? 'You\x27ll see your doctor. You can turn your own camera off during the call.'
                : 'The doctor keeps their camera off to save your data. You\x27ll still talk face to face if you both switch it on.',
            style: theme.bodySmall,
          ),
        ],
      ),
    );
  }
}
