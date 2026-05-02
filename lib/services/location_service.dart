import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _distanceKey = 'total_distance_km';

class DistanceManager {
  static final DistanceManager _instance = DistanceManager._internal();

  factory DistanceManager() {
    return _instance;
  }

  DistanceManager._internal();

  double _totalDistance = 0.0;

  double get totalDistance => _totalDistance;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _totalDistance = prefs.getDouble(_distanceKey) ?? 0.0;
  }

  Future<void> addDistance(double kilometers) async {
    _totalDistance += kilometers;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_distanceKey, _totalDistance);
  }

  Future<void> setDistance(double kilometers) async {
    _totalDistance = kilometers.clamp(0, 40000);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_distanceKey, _totalDistance);
  }

  Future<void> reset() async {
    _totalDistance = 0.0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_distanceKey);
  }
}

class LocationService {
  Position? _lastPosition;

  /// Request location permissions and return true if granted
  Future<bool> requestLocationPermission() async {
    final status = await Geolocator.requestPermission();
    return status == LocationPermission.whileInUse || status == LocationPermission.always;
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return position;
    } on Exception {
      return null;
    }
  }

  /// Stream of position updates with distance tracking
  Stream<double> get positionStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).asyncMap((position) async {
      double distanceKm = 0.0;

      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        distanceKm = distance / 1000; // Convert to kilometers
      }

      _lastPosition = position;
      return distanceKm;
    });
  }

  /// Reset tracking
  void reset() {
    _lastPosition = null;
  }
}
