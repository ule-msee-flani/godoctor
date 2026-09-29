import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../services/chemist_matching.dart';
import '../../location/location_picker_screen.dart'
    show mapTilesEnabledProvider;
import 'pharmacies_screen.dart';

/// Pharmacies on a map: a pin for each, you in the middle; tap a pin to
/// see the pharmacy and open its page.
class PharmacyMap extends ConsumerStatefulWidget {
  const PharmacyMap({super.key, required this.pharmacies, required this.at});

  final List<RankedPharmacy> pharmacies;
  final MatchPoint? at;

  @override
  ConsumerState<PharmacyMap> createState() => _PharmacyMapState();
}

class _PharmacyMapState extends ConsumerState<PharmacyMap> {
  String? _picked;

  @override
  Widget build(BuildContext context) {
    final placed = [
      for (final r in widget.pharmacies)
        if (r.chemist.hasLocation) r,
    ];
    if (!ref.watch(mapTilesEnabledProvider)) {
      return const Center(child: Text('The map is off to save data.'));
    }
    final center = widget.at != null
        ? LatLng(widget.at!.lat, widget.at!.lng)
        : placed.isNotEmpty
        ? LatLng(placed.first.chemist.lat!, placed.first.chemist.lng!)
        : const LatLng(-1.2864, 36.8172);
    final picked = placed.where((r) => r.chemist.userId == _picked).firstOrNull;
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onTap: (_, _) => setState(() => _picked = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.godoctor.godoctor_app',
            ),
            MarkerLayer(
              markers: [
                if (widget.at != null)
                  Marker(
                    point: LatLng(widget.at!.lat, widget.at!.lng),
                    width: 22,
                    height: 22,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x551B63F2), blurRadius: 10),
                        ],
                      ),
                    ),
                  ),
                for (final r in placed)
                  Marker(
                    point: LatLng(r.chemist.lat!, r.chemist.lng!),
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () => setState(() => _picked = r.chemist.userId),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _picked == r.chemist.userId ? 1.25 : 1,
                        child: Icon(
                          LucideIcons.mapPin,
                          size: 40,
                          color: _picked == r.chemist.userId
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SimpleAttributionWidget(
              source: Text('OpenStreetMap contributors'),
            ),
          ],
        ),
        if (placed.isEmpty)
          const Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('No pharmacies with a location yet.'),
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: picked == null
                ? const SizedBox.shrink()
                : PharmacyCard(
                    key: ValueKey(picked.chemist.userId),
                    chemist: picked.chemist,
                    km: picked.km,
                  ),
          ),
        ),
      ],
    );
  }
}
