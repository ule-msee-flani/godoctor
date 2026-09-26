import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_colors.dart';
import '../../services/geocoding.dart';
import '../../services/location_service.dart';

final geocoderProvider = Provider<Geocoder>((ref) => Geocoder());

/// Map tiles are fetched from OpenStreetMap; tests switch them off.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

const _nairobi = LatLng(-1.2921, 36.8219);

/// Pick a place on a free OpenStreetMap map: search by name, drag the map
/// under the pin, or jump to "my location". Pops the chosen [Place] with a
/// readable name such as "Ruiru, Kiambu, Kenya".
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial, this.title});

  final Place? initial;
  final String? title;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _map = MapController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  Timer? _reverseDebounce;

  late LatLng _center = widget.initial == null
      ? _nairobi
      : LatLng(widget.initial!.lat, widget.initial!.lng);
  late String? _name = widget.initial?.name;
  bool _naming = false;
  bool _locating = false;
  bool _searching = false;
  List<Place> _results = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      // Start from where the user is, if they allow it.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _useMyLocation(quiet: true),
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _searchCtrl.dispose();
    _map.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _onSearchChanged(String q) {
    _searchDebounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 700), () async {
      setState(() => _searching = true);
      try {
        final r = await ref.read(geocoderProvider).search(q);
        if (mounted) setState(() => _results = r);
      } catch (_) {
        if (mounted) _toast('Could not search places. Check your connection.');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _moveTo(LatLng point, {String? name}) {
    setState(() {
      _center = point;
      _results = const [];
      if (name != null) _name = name;
    });
    if (ref.read(mapTilesEnabledProvider)) _map.move(point, 16);
    if (name == null) _lookUpName();
  }

  void _lookUpName() {
    _reverseDebounce?.cancel();
    setState(() => _naming = true);
    _reverseDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final place = await ref
            .read(geocoderProvider)
            .reverse(_center.latitude, _center.longitude);
        if (mounted) setState(() => _name = place?.name);
      } catch (_) {
        if (mounted) setState(() => _name = null);
      } finally {
        if (mounted) setState(() => _naming = false);
      }
    });
  }

  Future<void> _useMyLocation({bool quiet = false}) async {
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      if (mounted) _moveTo(LatLng(loc.lat, loc.lng));
    } on LocationException catch (e) {
      if (mounted && !quiet) _toast(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final tiles = ref.watch(mapTilesEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Choose location')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search a place, e.g. Ruiru',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
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
          ),
          Expanded(
            child: Stack(
              children: [
                if (tiles)
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: _center,
                      initialZoom: 15,
                      onMapEvent: (event) {
                        if (event is MapEventMoveEnd &&
                            event.source != MapEventSource.mapController) {
                          _center = event.camera.center;
                          _lookUpName();
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.godoctor.godoctor_app',
                      ),
                      const SimpleAttributionWidget(
                        source: Text('OpenStreetMap contributors'),
                      ),
                    ],
                  )
                else
                  const ColoredBox(color: AppColors.primarySofter),
                // Fixed pin in the centre: move the map under it.
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 36),
                      child: Icon(
                        LucideIcons.mapPin,
                        size: 40,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 0,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final p in _results)
                            ListTile(
                              dense: true,
                              leading: const Icon(LucideIcons.mapPin, size: 18),
                              title: Text(p.name),
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                _searchCtrl.text = p.name;
                                _moveTo(LatLng(p.lat, p.lng), name: p.name);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.mapPin,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _naming
                              ? 'Finding the place name…'
                              : (_name ?? 'Move the map to your place'),
                          style: theme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 56),
                        ),
                        onPressed: _locating ? null : () => _useMyLocation(),
                        icon: _locating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(LucideIcons.locateFixed, size: 18),
                        label: const Text('My location'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _naming || _name == null
                              ? null
                              : () => Navigator.of(context).pop(
                                  Place(
                                    name: _name!,
                                    lat: _center.latitude,
                                    lng: _center.longitude,
                                  ),
                                ),
                          child: const Text('Use this location'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
