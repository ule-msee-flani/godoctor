import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_assets.dart';
import '../../../core/widgets/app_image.dart';
import '../widgets/emergency_stop_view.dart';
import '../widgets/specialty_tiles.dart';
import 'specialty_content.dart';

/// Shared layout for a specialty's page: picture, plain-language description,
/// when to see one, what a video consultation can do, when it's an emergency,
/// and buttons to find a doctor. The words come from the specialty's own file
/// in `content/`.
class SpecialtyPage extends StatelessWidget {
  const SpecialtyPage({super.key, required this.content});

  final SpecialtyContent content;

  @override
  Widget build(BuildContext context) {
    final meta = specialtyMetaForSlug(content.slug);
    final theme = Theme.of(context).textTheme;
    final query = Uri.encodeQueryComponent(content.name);

    // Wide hero picture if supplied, otherwise the tile picture, otherwise a
    // branded gradient.
    final heroBase = meta == null
        ? ''
        : (AppAssets.find(meta.heroBase) != null
              ? meta.heroBase
              : meta.imageBase);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250,
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: theme.titleLarge?.copyWith(color: Colors.white),
            title: Text(meta?.label ?? content.title),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(
                    assetPath: heroBase,
                    borderRadius: 0,
                    placeholderIcon: meta?.icon ?? LucideIcons.stethoscope,
                    placeholderLabel: heroBase,
                    showPlaceholderContent: false,
                  ),
                  // Keeps the title readable over any photo.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x330B1730), Color(0xCC0B1730)],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
                    child: Text(
                      content.title,
                      style: theme.headlineMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  content.tagline,
                  style: theme.titleMedium?.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: 18),
                _SectionTitle('What is ${meta?.label ?? content.name}?'),
                const SizedBox(height: 8),
                for (final p in content.about)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(p, style: theme.bodyLarge),
                  ),
                const SizedBox(height: 14),
                const _SectionTitle('Common reasons to see a specialist'),
                const SizedBox(height: 10),
                _BulletCard(
                  items: content.commonReasons,
                  icon: LucideIcons.circleCheck,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 22),
                const _SectionTitle('How a video consultation can help'),
                const SizedBox(height: 10),
                _BulletCard(
                  items: content.onlineHelp,
                  icon: LucideIcons.video,
                  color: AppColors.accentTeal,
                ),
                const SizedBox(height: 22),
                _UrgentCard(signs: content.urgentSigns),
                const SizedBox(height: 18),
                Text(
                  'This page is general information and is not medical advice. '
                  'A doctor can advise you on your own situation.',
                  style: theme.bodySmall,
                ),
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                icon: const Icon(LucideIcons.search, size: 18),
                label: Text(content.findDoctorsLabel),
                onPressed: () =>
                    context.go('/patient/doctors?specialty=$query'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () =>
                    context.push('/patient/intake?specialty=$query'),
                child: const Text('Or see a doctor now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class _BulletCard extends StatelessWidget {
  const _BulletCard({
    required this.items,
    required this.icon,
    required this.color,
  });

  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i],
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UrgentCard extends StatelessWidget {
  const _UrgentCard({required this.signs});

  final List<String> signs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.siren, color: AppColors.danger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Get urgent help instead if you have',
                  style: theme.titleMedium?.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final s in signs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(Icons.circle, size: 6, color: AppColors.danger),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s,
                      style: theme.bodyLarge?.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: () => launchDialer('999'),
            icon: const Icon(LucideIcons.phoneCall, size: 18),
            label: const Text('Call 999 (Emergency)'),
          ),
        ],
      ),
    );
  }
}
