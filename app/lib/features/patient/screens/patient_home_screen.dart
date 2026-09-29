import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/local_touch.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../services/emergency_check.dart';
import '../../../services/specialty_search.dart';
import '../family/family_providers.dart';
import '../family/family_session_screen.dart';
import '../home/emergency_strip.dart';
import '../home/smart_home_card.dart';
import '../widgets/emergency_stop_view.dart' show launchDialer;
import '../widgets/promo_banner_carousel.dart';
import '../widgets/specialty_tiles.dart';
import '../../../core/widgets/motion.dart';
import '../../../services/live_updates.dart';
import '../visits/visit_widgets.dart';
import '../appointments/appointments.dart';
import '../../selfcare/selfcare_screens.dart';

class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startIntake(String specialty, {String? symptoms}) {
    final params = <String, String>{
      'specialty': specialty,
      if (symptoms != null && symptoms.isNotEmpty) 'symptoms': symptoms,
    };
    context.push(
      Uri(path: '/patient/intake', queryParameters: params).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentPatientProfileProvider).valueOrNull;
    final name = profile?.name ?? '';
    final query = _searchCtrl.text.trim();
    final searching = query.isNotEmpty;
    final unread = ref.watch(unreadNotificationCountProvider);
    final familyInvites =
        ref.watch(myFamilySessionInvitesProvider).valueOrNull ?? const [];
    final avatarPath = ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl;

    return Scaffold(
      body: SafeArea(
        child: LiveRefresh(
          // Pulling down also reconnects the live consultation, so a
          // payment confirmed while offline shows up.
          onRefresh: () async {
            ref
              ..invalidate(activeConsultationProvider)
              ..invalidate(myAppointmentsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalTouch.greeting(DateTime.now()),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name.isNotEmpty
                                      ? name.split(' ').first
                                      : LocalTouch.welcome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const HandshakeWave(),
                            ],
                          ),
                          if ((profile?.locationName ?? '').trim().isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  context.push('/patient/profile/location'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    LucideIcons.mapPin,
                                    size: 13,
                                    color: AppColors.inkSoft,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      shortPlace(profile!.locationName!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.inkSoft),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    NotificationBell(
                      count: unread,
                      onPressed: () => context.push('/patient/notifications'),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => context.go('/patient/profile'),
                      child: UserAvatar(
                        name: name.isEmpty ? '?' : name,
                        path: avatarPath,
                        radius: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hint: const RotatingHint(),
                    prefixIcon: const Icon(LucideIcons.search, size: 20),
                    suffixIcon: searching
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () => setState(_searchCtrl.clear),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (searching)
                _SearchResults(query: query, onPick: _startIntake)
              else ...[
                if (familyInvites.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FamilyInviteBanner(consultationIds: familyInvites),
                  ),
                // Booked appointments, like a ticket with the doctor's photo.
                const FadeSlideIn(child: UpcomingAppointmentsHero()),
                const SizedBox(height: 16),
                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SmartHomeCard(
                      showAppointments: false,
                      onFeeling: (specialty, symptom) =>
                          _startIntake(specialty, symptoms: symptom),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  index: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PrimaryTile(
                            image: 'assets/images/home/see_doctor',
                            fallbackIcon: LucideIcons.video,
                            alignment: const Alignment(0, -0.6),
                            title: 'See a Doctor',
                            subtitle: 'Video consult now',
                            onTap: () => context.push('/patient/intake'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrimaryTile(
                            image: 'assets/images/home/order_medicine',
                            fallbackIcon: LucideIcons.pill,
                            title: 'Order Medicine',
                            subtitle: 'From chemists near you',
                            onTap: () =>
                                context.push('/patient/medicine-search'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Now and then, a small self-care practice for the moment.
                const FadeSlideIn(
                  index: 2,
                  child: SelfCareSuggestionCard(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  ),
                ),
                // The latest visits, right on home.
                const FadeSlideIn(index: 2, child: RecentVisitsSection()),
                const SizedBox(height: 22),
                const FadeSlideIn(index: 2, child: PromoBannerCarousel()),
                const SizedBox(height: 22),
                FadeSlideIn(
                  index: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Specialties',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/patient/doctors'),
                          child: const Text('Browse doctors'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FadeSlideIn(
                  index: 4,
                  child: SpecialtyCarousel(
                    onSelected: (meta) =>
                        context.push('/patient/specialty/${meta.slug}'),
                  ),
                ),
                const SizedBox(height: 24),
                const FadeSlideIn(
                  index: 5,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: EmergencyStrip(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Ruiru, Kiambu, Kenya" -> "Ruiru, Kiambu".
String shortPlace(String place) {
  final parts = [
    for (final p in place.split(','))
      if (p.trim().isNotEmpty && p.trim().toLowerCase() != 'kenya') p.trim(),
  ];
  return parts.take(2).join(', ');
}

/// The search hint that keeps suggesting things to try.
class RotatingHint extends StatefulWidget {
  const RotatingHint({super.key});

  static const terms = [
    'headache',
    'skin rash',
    'cough',
    'back pain',
    'Orthopedics',
    'my child has a fever',
    'stomach ache',
  ];

  @override
  State<RotatingHint> createState() => _RotatingHintState();
}

class _RotatingHintState extends State<RotatingHint> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (mounted) setState(() => _i = (_i + 1) % RotatingHint.terms.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(a),
          child: child,
        ),
      ),
      child: Text(
        'Try "${RotatingHint.terms[_i]}"',
        key: ValueKey(_i),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AppColors.inkFaint),
      ),
    );
  }
}

/// Home shortcut: a photo on top, bold title and lighter subtitle below.
class _PrimaryTile extends StatelessWidget {
  const _PrimaryTile({
    required this.image,
    required this.fallbackIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.alignment = Alignment.center,
  });

  /// Asset path without extension (see assets/README.md).
  final String image;
  final IconData fallbackIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Pressable(
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppImage(
                assetPath: image,
                height: 118,
                borderRadius: 0,
                alignment: alignment,
                placeholderIcon: fallbackIcon,
                placeholderLabel: title,
                showPlaceholderContent: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: AppColors.ink,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline results under the search field. Runs the same emergency check as
/// the intake form so a query like "chest pain" is never met with a cheerful
/// "book a cardiologist" -- it gets the emergency message instead.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query, required this.onPick});

  final String query;
  final void Function(String specialty, {String? symptoms}) onPick;

  @override
  Widget build(BuildContext context) {
    if (checkForEmergency([query]).flagged) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.siren,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This may be a medical emergency',
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: AppColors.danger),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Please call emergency services or go to the nearest hospital now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => launchDialer('999'),
                icon: const Icon(LucideIcons.phoneCall, size: 18),
                label: const Text('Call 999'),
              ),
            ],
          ),
        ),
      );
    }

    final suggestions = suggestSpecialties(query);
    if (suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Keep typing to see matching specialties.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested specialties',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          for (final s in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    final isNameMatch = s.specialty.toLowerCase().contains(
                      query.toLowerCase(),
                    );
                    onPick(s.specialty, symptoms: isNameMatch ? null : query);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            specialtyMetaFor(s.specialty).icon,
                            color: AppColors.ink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.specialty,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if (s.matchedOn != null)
                                Text(
                                  'Matches "${s.matchedOn}"',
                                  style: Theme.of(context).textTheme.bodySmall,
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
        ],
      ),
    );
  }
}
