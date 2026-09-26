import 'dart:convert';

import 'package:http/http.dart' as http;

/// A place with a readable name.
class Place {
  const Place({required this.name, required this.lat, required this.lng});

  /// Short readable name, e.g. "Ruiru, Kiambu, Kenya".
  final String name;
  final double lat;
  final double lng;
}

/// Place names <-> coordinates using OpenStreetMap's free Nominatim service
/// (no API key). Its usage policy allows light use like this: about one
/// request per second, with attribution. For heavy production traffic,
/// switch [baseUrl] to a hosted Nominatim (or LocationIQ/MapTiler) -- the
/// response format is the same.
class Geocoder {
  Geocoder({
    http.Client? client,
    this.baseUrl = 'https://nominatim.openstreetmap.org',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  static const _headers = {
    // Browsers ignore this (they send their own); apps identify themselves.
    'User-Agent': 'GoDoctor/1.0 (com.godoctor.godoctor_app)',
    'Accept-Language': 'en',
  };

  /// Places in Kenya matching [query] (best first).
  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final uri = Uri.parse('$baseUrl/search').replace(
      queryParameters: {
        'q': q,
        'format': 'jsonv2',
        'addressdetails': '1',
        'countrycodes': 'ke',
        'limit': '6',
      },
    );
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return const [];
    final list = jsonDecode(res.body) as List;
    return [
      for (final m in list.cast<Map<String, dynamic>>())
        Place(
          name: shortName(m),
          lat: double.parse(m['lat'] as String),
          lng: double.parse(m['lon'] as String),
        ),
    ];
  }

  /// The readable name of the place at [lat], [lng], or null if unknown.
  Future<Place?> reverse(double lat, double lng) async {
    final uri = Uri.parse('$baseUrl/reverse').replace(
      queryParameters: {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '16',
      },
    );
    final res = await _client.get(uri, headers: _headers);
    if (res.statusCode != 200) return null;
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    if (m['error'] != null) return null;
    return Place(name: shortName(m), lat: lat, lng: lng);
  }

  /// "Ruiru, Kiambu, Kenya" rather than Nominatim's long display_name:
  /// neighbourhood/area, town, county, country.
  static String shortName(Map<String, dynamic> result) {
    final a = (result['address'] as Map?)?.cast<String, dynamic>() ?? const {};
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    final area = pick([
      'suburb',
      'neighbourhood',
      'quarter',
      'village',
      'hamlet',
    ]);
    final town = pick(['town', 'city', 'municipality', 'city_district']);
    final county = pick([
      'county',
      'state_district',
      'state',
    ])?.replaceAll(RegExp(r'\s+County$'), '');
    final country = pick(['country']);

    final parts = <String>[];
    for (final p in [area, town, county, country]) {
      if (p != null && !parts.contains(p)) parts.add(p);
    }
    if (parts.length >= 2) return parts.join(', ');
    return (result['display_name'] as String?) ?? parts.join(', ');
  }
}
