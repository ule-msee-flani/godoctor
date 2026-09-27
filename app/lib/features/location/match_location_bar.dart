import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../services/chemist_matching.dart';
import '../../services/geocoding.dart';
import 'location_picker_screen.dart' show geocoderProvider;

/// Call when a "find a chemist" screen opens: quietly uses the phone's
/// location if it's already allowed; otherwise, once in a while, offers to
/// turn it on for the closest matches.
Future<void> offerPreciseLocation(BuildContext context, WidgetRef ref) async {
  final m = ref.read(matchingLocationProvider.notifier);
  if (await m.useDevice()) return;
  if (!await m.shouldOfferPrecise() || !context.mounted) return;
  m.markOffered();
  final turnOn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(LucideIcons.mapPinned, size: 40, color: AppColors.ink),
              const SizedBox(height: 12),
              Text(
                'See the chemists closest to you',
                textAlign: TextAlign.center,
                style: theme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Turn on location and we\'ll show the chemists nearest to where '
                'you are right now.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(LucideIcons.locateFixed, size: 18),
                label: const Text('Turn on location'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (turnOn == true) {
    await m.enablePrecise();
  } else {
    await m.declinePrecise();
  }
}

/// "Near Kilimani · Change": where chemists are matched from, and a way to
/// pick somewhere else.
class MatchLocationBar extends ConsumerWidget {
  const MatchLocationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context).textTheme;
    final at = ref.watch(matchingLocationProvider);
    final label = at == null
        ? 'Choose where to find chemists'
        : at.label == null || at.label!.isEmpty
        ? 'Nearest to you'
        : 'Near ${_short(at.label!)}';
    return Material(
      color: AppColors.primarySofter,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showLocationFilterSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(
                at?.source == MatchSource.device
                    ? LucideIcons.locateFixed
                    : LucideIcons.mapPin,
                size: 18,
                color: AppColors.ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
              ),
              Text(
                'Change',
                style: theme.labelLarge?.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Kilimani, Nairobi, Kenya" -> "Kilimani, Nairobi".
  static String _short(String name) {
    final parts = name.split(',').map((p) => p.trim()).toList();
    if (parts.length > 1 && parts.last.toLowerCase() == 'kenya') {
      parts.removeLast();
    }
    return parts.take(2).join(', ');
  }
}

/// Search for a place (or use the current location) to find chemists near.
Future<void> showLocationFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LocationFilterSheet(),
  );
}

class _LocationFilterSheet extends ConsumerStatefulWidget {
  const _LocationFilterSheet();

  @override
  ConsumerState<_LocationFilterSheet> createState() =>
      _LocationFilterSheetState();
}

class _LocationFilterSheetState extends ConsumerState<_LocationFilterSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  bool _searching = false;
  bool _locating = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (q.trim().length < 3) {
        if (mounted) setState(() => _results = const []);
        return;
      }
      setState(() => _searching = true);
      try {
        final r = await ref.read(geocoderProvider).search(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) setState(() => _results = const []);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _useHere() async {
    setState(() => _locating = true);
    final ok = await ref
        .read(matchingLocationProvider.notifier)
        .enablePrecise();
    if (!mounted) return;
    setState(() => _locating = false);
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t get your location. Search for a place instead.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Find chemists near…', style: theme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search a town, estate or street',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                LucideIcons.locateFixed,
                color: AppColors.ink,
              ),
              title: const Text('Use my current location'),
              trailing: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _locating ? null : _useHere,
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in _results)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        LucideIcons.mapPin,
                        color: AppColors.inkSoft,
                      ),
                      title: Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        ref
                            .read(matchingLocationProvider.notifier)
                            .useCustom(p);
                        Navigator.pop(context);
                      },
                    ),
                  if (!_searching &&
                      _results.isEmpty &&
                      _ctrl.text.trim().length >= 3)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'No places found. Try a nearby town or estate.',
                        textAlign: TextAlign.center,
                        style: theme.bodySmall,
                      ),
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
