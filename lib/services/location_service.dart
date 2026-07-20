import 'package:geolocator/geolocator.dart';

/// Handles location permission + current GPS position.
///
/// Nearby sightings/hotspots are meaningless without a fix. We request
/// permission on demand and surface user-readable [LocationException]s
/// rather than raw platform errors.
class LocationService {
  /// Returns the current position, requesting permission if needed.
  /// Throws a [LocationException] with a user-friendly message on failure.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
          'Location services are turned off. Enable them in your device settings.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationException(
            'Location permission denied. The Life List needs it to find sightings near you.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Location permission permanently denied. Enable it in app settings.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }
}

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}
