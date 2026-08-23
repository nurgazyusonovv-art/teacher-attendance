import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });
}

class LocationService {
  /// Түзмөктүн GPS кызматы жангандыгын жана уруксат берилгенин текшерип, учурдагы координатаны алат.
  static Future<LocationResult> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('LOCATION_SERVICES_DISABLED');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('LOCATION_PERMISSION_DENIED');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('LOCATION_PERMISSION_PERMANENTLY_DENIED');
    }

    // High accuracy GPS position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );

    return LocationResult(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
    );
  }
}
