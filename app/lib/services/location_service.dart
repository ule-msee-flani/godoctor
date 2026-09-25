import 'package:geolocator/geolocator.dart';

/// Thrown with a message that is safe to show the user as-is.
class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// One-shot current position, used to store the patient's location so
/// "nearest chemist" can sort by distance. Works on web (browser prompt,
/// HTTPS/localhost only) and on Android.
Future<({double lat, double lng})> getCurrentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationException(
      'Location services are turned off on this device.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationException('Location permission was denied.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw const LocationException(
      'Location is blocked. Allow it in your browser or app settings, then try again.',
    );
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return (lat: position.latitude, lng: position.longitude);
  } catch (_) {
    throw const LocationException(
      'Could not get your location. Please try again.',
    );
  }
}
