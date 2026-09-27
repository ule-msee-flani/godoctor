import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/drug.dart';
import '../data/models/patient_profile.dart';
import '../data/providers/auth_providers.dart';
import '../features/location/location_picker_screen.dart' show geocoderProvider;
import 'distance.dart';
import 'geocoding.dart';

/// Where chemists are matched from. The patient only ever sees "near a
/// place"; which of these it came from is the matching's business.
enum MatchSource { device, profile, custom }

class MatchPoint {
  const MatchPoint({
    required this.lat,
    required this.lng,
    required this.source,
    this.label,
  });

  final double lat;
  final double lng;
  final MatchSource source;

  /// A readable place name, when known.
  final String? label;

  MatchPoint withLabel(String? l) =>
      MatchPoint(lat: lat, lng: lng, source: source, label: l);
}

/// The best point to match chemists from: the phone's live location when
/// the patient allows it, otherwise the location saved in their profile, or
/// a place they searched for themselves.
final matchingLocationProvider =
    StateNotifierProvider<MatchingLocation, MatchPoint?>((ref) {
      final m = MatchingLocation(ref.read(geocoderProvider));
      ref.listen<AsyncValue<PatientProfile?>>(
        currentPatientProfileProvider,
        (_, next) => m.useProfile(next.valueOrNull),
        fireImmediately: true,
      );
      return m;
    });

class MatchingLocation extends StateNotifier<MatchPoint?> {
  MatchingLocation(this._geocoder) : super(null);

  final Geocoder _geocoder;
  bool _askedThisSession = false;
  static const _declinedKey = 'precise_location_declined_at';

  /// The saved profile location, unless something more precise is in use.
  void useProfile(PatientProfile? p) {
    if (p?.locationLat == null || p?.locationLng == null) return;
    if (state != null && state!.source != MatchSource.profile) return;
    state = MatchPoint(
      lat: p!.locationLat!,
      lng: p.locationLng!,
      source: MatchSource.profile,
      label: p.locationName,
    );
  }

  /// A place the patient searched for ("chemists near Westlands").
  void useCustom(Place place) {
    state = MatchPoint(
      lat: place.lat,
      lng: place.lng,
      source: MatchSource.custom,
      label: place.name,
    );
  }

  /// The phone's current position. Without [ask], only works if location
  /// is already on and allowed (no prompts).
  Future<bool> useDevice({bool ask = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return false;
      state = MatchPoint(
        lat: pos.latitude,
        lng: pos.longitude,
        source: MatchSource.device,
      );
      // Name the area in the background ("near Kilimani").
      unawaited(
        _geocoder
            .reverse(pos.latitude, pos.longitude)
            .then((p) {
              if (mounted && state?.source == MatchSource.device) {
                state = state!.withLabel(p?.name);
              }
            })
            .catchError((_) {}),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether to offer turning on location now (not if it's already in
  /// use, already offered this session, or declined in the last 3 days).
  Future<bool> shouldOfferPrecise() async {
    if (_askedThisSession) return false;
    if (state?.source == MatchSource.device ||
        state?.source == MatchSource.custom) {
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = DateTime.tryParse(prefs.getString(_declinedKey) ?? '');
      if (at != null &&
          DateTime.now().difference(at) < const Duration(days: 3)) {
        return false;
      }
    } catch (_) {}
    return true;
  }

  void markOffered() => _askedThisSession = true;

  Future<void> declinePrecise() async {
    _askedThisSession = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_declinedKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Turn location on: the permission prompt, or the phone's location
  /// settings when it's switched off (then try again when they come back).
  Future<bool> enablePrecise() async {
    _askedThisSession = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
        await _resumed(const Duration(seconds: 90));
      }
      return useDevice(ask: true);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _resumed(Duration timeout) {
    final done = Completer<void>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future
        .timeout(timeout, onTimeout: () {})
        .whenComplete(listener.dispose);
  }
}

/// One chemist's offer with its distance from the match point.
typedef RankedStock = ({ChemistInventoryItem item, double? km});

/// Orders chemists by how convenient they are: close ones first (in bands,
/// so a slightly further chemist that's much cheaper can still come
/// first), then price, then how much stock they have. Chemists without a
/// location go last.
List<RankedStock> rankByConvenience(
  List<ChemistInventoryItem> items,
  MatchPoint? at,
) {
  final ranked = [
    for (final i in items)
      (
        item: i,
        km: at == null || i.chemistLat == null || i.chemistLng == null
            ? null
            : distanceKm(at.lat, at.lng, i.chemistLat!, i.chemistLng!),
      ),
  ];
  int band(double km) => switch (km) {
    < 1 => 0,
    < 3 => 1,
    < 7 => 2,
    < 15 => 3,
    < 40 => 4,
    _ => 5,
  };
  ranked.sort((a, b) {
    if (a.km == null && b.km != null) return 1;
    if (b.km == null && a.km != null) return -1;
    if (a.km != null && b.km != null) {
      final d = band(a.km!).compareTo(band(b.km!));
      if (d != 0) return d;
    }
    final p = a.item.price.compareTo(b.item.price);
    if (p != 0) return p;
    if (a.km != null && b.km != null) {
      final d = a.km!.compareTo(b.km!);
      if (d != 0) return d;
    }
    return b.item.quantity.compareTo(a.item.quantity);
  });
  return ranked;
}

/// "800 m" / "3.4 km".
String distanceLabel(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
