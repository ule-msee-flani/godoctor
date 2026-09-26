import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/app_image.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../data/providers/appointment_providers.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/notification_providers.dart';
import '../../../services/emergency_check.dart';
import '../../../services/specialty_search.dart';
import '../family/family_providers.dart';
import '../family/family_session_screen.dart';
import '../widgets/emergency_stop_view.dart' show launchDialer;
import '../widgets/promo_banner_carousel.dart';
import '../widgets/specialty_tiles.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

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
    final upcoming = ref.watch(upcomingAppointmentsProvider).valueOrNull;
    final familyInvites =
        ref.watch(myFamilySessionInvitesProvider).valueOrNull ?? const [];
    final avatarPath = ref.watch(currentAppUserProvider).valueOrNull?.avatarUrl;

    return Scaffold(
      body: SafeArea(
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
                          _greeting(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name.isNotEmpty
                                    ? name.split(' ').first
                                    : 'Welcome',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _Handshake(),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 9 ? '9+' : '$unread'),
                    offset: const Offset(-6, 4),
                    child: IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(LucideIcons.bell),
                      onPressed: () => context.push('/patient/notifications'),
                    ),
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
                  hintText: 'Search a symptom or specialty',
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
              if (upcoming != null && upcoming.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _UpcomingCard(
                    when: upcoming.first.scheduledFor,
                    specialty: upcoming.first.specialtyRequested,
                    live: upcoming.first.canStartNow,
                    onTap: () => context.push(
                      '/patient/appointment/${upcoming.first.id}',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Padding(
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
                        onTap: () => context.push('/patient/medicine-search'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const PromoBannerCarousel(),
              const SizedBox(height: 22),
              Padding(
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
              const SizedBox(height: 12),
              SpecialtyRow(
                onSelected: (meta) =>
                    context.push('/patient/specialty/${meta.slug}'),
              ),
            ],
          ],
        ),
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
    return Material(
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
    );
  }
}

/// The handshake beside the greeting: a friendly little shake when the home
/// screen opens, then still.
class _Handshake extends StatefulWidget {
  const _Handshake();

  @override
  State<_Handshake> createState() => _HandshakeState();
}

class _HandshakeState extends State<_Handshake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hello',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          // Three quick shakes that die away.
          final t = _c.value;
          final swing = math.sin(t * 3 * 2 * math.pi) * (1 - t);
          final dy = -3 * swing.abs();
          final angle = 0.14 * swing;
          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(angle: angle, child: child),
          );
        },
        child: const Icon(
          LucideIcons.handshake,
          size: 26,
          color: AppColors.ink,
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

/// "Next appointment" strip shown when the patient has something booked.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.when,
    required this.specialty,
    required this.live,
    required this.onTap,
  });

  final DateTime? when;
  final String specialty;
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  LucideIcons.calendarClock,
                  color: AppColors.ink,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live ? 'Your appointment is ready' : 'Next appointment',
                      style: theme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                    Text(
                      when == null ? specialty : formatRelativeSlot(when!),
                      style: theme.titleMedium?.copyWith(color: Colors.white),
                    ),
                    Text(
                      specialty,
                      style: theme.bodySmall?.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
