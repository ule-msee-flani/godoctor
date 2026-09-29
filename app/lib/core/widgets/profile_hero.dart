import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../utils/format.dart';
import 'curved_clipper.dart';

/// A person's (or pharmacy's) page: their own photo across the top half
/// with the curved bottom edge used on sign-in, the details scrolling up
/// over it, and a slim bar with their name once the photo is gone.
class ProfileHeroScaffold extends StatefulWidget {
  const ProfileHeroScaffold({
    super.key,
    required this.title,
    required this.children,
    this.photoUrl,
    this.fallbackIcon = LucideIcons.userRound,
    this.photoAlignment = const Alignment(0, -0.3),
    this.bottomBar,
    this.heightFactor = 0.48,
    this.actions = const [],
  });

  /// Shown in the bar after scrolling (their name).
  final String title;
  final List<Widget> children;

  /// Their photo; without one, a branded panel with their initials.
  final String? photoUrl;
  final IconData fallbackIcon;
  final Alignment photoAlignment;
  final Widget? bottomBar;
  final double heightFactor;

  /// Buttons at the top right (e.g. save to favourites).
  final List<Widget> actions;

  @override
  State<ProfileHeroScaffold> createState() => _ProfileHeroScaffoldState();
}

class _ProfileHeroScaffoldState extends State<ProfileHeroScaffold> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  late double _height;

  void _onScroll() {
    final c = _scroll.offset > _height - kToolbarHeight - 40;
    if (c != _collapsed) setState(() => _collapsed = c);
  }

  Widget _fallback() => DecoratedBox(
    decoration: const BoxDecoration(gradient: AppColors.heroGradient),
    child: Center(
      child: Text(
        initialsOf(widget.title),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 88,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    _height = (MediaQuery.sizeOf(context).height * widget.heightFactor).clamp(
      260.0,
      480.0,
    );
    final url = widget.photoUrl;
    final back = Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Center(
        child: IconButton.filled(
          tooltip: 'Back',
          style: IconButton.styleFrom(
            backgroundColor: _collapsed
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.92),
            foregroundColor: AppColors.ink,
          ),
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light status bar icons over the photo, dark once the bar is white.
      value:
          (_collapsed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light)
              .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.white,
        bottomNavigationBar: widget.bottomBar,
        body: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: _height,
              automaticallyImplyLeading: false,
              leading: back,
              actions: [...widget.actions, const SizedBox(width: 12)],
              backgroundColor: _collapsed
                  ? AppColors.white
                  : Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: AnimatedOpacity(
                opacity: _collapsed ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: ClipPath(
                  clipper: const InwardCurveClipper(depth: 26),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (url == null)
                        _fallback()
                      else
                        Image.network(
                          url,
                          fit: BoxFit.cover,
                          alignment: widget.photoAlignment,
                          errorBuilder: (_, _, _) => _fallback(),
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : _fallback(),
                        ),
                      // Keeps the back button and status bar readable.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment(0, -0.4),
                            colors: [Color(0x55000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate(widget.children),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One figure in a profile's stats row ("12 yrs · Experience").
class ProfileStat extends StatelessWidget {
  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.icon,
  });

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.ink),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The stats row: figures separated by thin dividers, in one card.
class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0B1730),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                const VerticalDivider(width: 1, color: AppColors.border),
              stats[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A section heading on a profile.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
