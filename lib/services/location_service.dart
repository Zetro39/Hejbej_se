import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

const String _distanceKey = 'totalDistance';

class DistanceManager {
  static final DistanceManager _instance = DistanceManager._internal();

  factory DistanceManager() {
    return _instance;
  }

  DistanceManager._internal();

  double _totalDistance = 0.0;
  double _weeklyDistance = 0.0;
  double _monthlyDistance = 0.0;
  String? _lastDistanceUpdateStr;

  double get totalDistance => _totalDistance;
  double get weeklyDistance => _weeklyDistance;
  double get monthlyDistance => _monthlyDistance;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _totalDistance = prefs.getDouble(_distanceKey) ?? 0.0;
    _weeklyDistance = prefs.getDouble('weeklyDistance') ?? 0.0;
    _monthlyDistance = prefs.getDouble('monthlyDistance') ?? 0.0;
    _lastDistanceUpdateStr = prefs.getString('lastDistanceUpdate');

    // Check if we need to reset weekly/monthly distances on startup
    final now = DateTime.now();
    if (_lastDistanceUpdateStr != null) {
      final lastUpdate = DateTime.tryParse(_lastDistanceUpdateStr!);
      if (lastUpdate != null) {
        if (!_isSameISOWeek(now, lastUpdate)) {
          _weeklyDistance = 0.0;
          await prefs.setDouble('weeklyDistance', 0.0);
        }
        if (now.month != lastUpdate.month || now.year != lastUpdate.year) {
          _monthlyDistance = 0.0;
          await prefs.setDouble('monthlyDistance', 0.0);
        }
      }
    }
  }

  bool _isSameISOWeek(DateTime date1, DateTime date2) {
    final monday1 = date1.subtract(Duration(days: date1.weekday - 1));
    final monday2 = date2.subtract(Duration(days: date2.weekday - 1));
    return monday1.year == monday2.year &&
        monday1.month == monday2.month &&
        monday1.day == monday2.day;
  }

  Future<void> addDistance(double kilometers) async {
    _totalDistance += kilometers;
    
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    // Reset if period changed since last update
    if (_lastDistanceUpdateStr != null) {
      final lastUpdate = DateTime.tryParse(_lastDistanceUpdateStr!);
      if (lastUpdate != null) {
        if (!_isSameISOWeek(now, lastUpdate)) {
          _weeklyDistance = 0.0;
        }
        if (now.month != lastUpdate.month || now.year != lastUpdate.year) {
          _monthlyDistance = 0.0;
        }
      }
    }
    
    _weeklyDistance += kilometers;
    _monthlyDistance += kilometers;
    _lastDistanceUpdateStr = now.toIso8601String();
    
    await prefs.setDouble(_distanceKey, _totalDistance);
    await prefs.setDouble('weeklyDistance', _weeklyDistance);
    await prefs.setDouble('monthlyDistance', _monthlyDistance);
    await prefs.setString('lastDistanceUpdate', _lastDistanceUpdateStr!);

    // Sync to Firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final limetky = prefs.getInt('limetkyBalance') ?? 0;
      await AuthService().updateDistanceLocal(_totalDistance, _weeklyDistance, _monthlyDistance, limetky);
    }
  }

  Future<void> setDistance(double kilometers) async {
    final oldTotal = _totalDistance;
    _totalDistance = kilometers.clamp(0, 40000);
    double delta = _totalDistance - oldTotal;
    if (delta < 0) delta = 0.0;
    
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    if (_lastDistanceUpdateStr != null) {
      final lastUpdate = DateTime.tryParse(_lastDistanceUpdateStr!);
      if (lastUpdate != null) {
        if (!_isSameISOWeek(now, lastUpdate)) {
          _weeklyDistance = 0.0;
        }
        if (now.month != lastUpdate.month || now.year != lastUpdate.year) {
          _monthlyDistance = 0.0;
        }
      }
    }
    
    _weeklyDistance += delta;
    _monthlyDistance += delta;
    _lastDistanceUpdateStr = now.toIso8601String();
    
    await prefs.setDouble(_distanceKey, _totalDistance);
    await prefs.setDouble('weeklyDistance', _weeklyDistance);
    await prefs.setDouble('monthlyDistance', _monthlyDistance);
    await prefs.setString('lastDistanceUpdate', _lastDistanceUpdateStr!);

    // Sync to Firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final limetky = prefs.getInt('limetkyBalance') ?? 0;
      await AuthService().updateDistanceLocal(_totalDistance, _weeklyDistance, _monthlyDistance, limetky);
    }
  }

  Future<void> reset() async {
    _totalDistance = 0.0;
    _weeklyDistance = 0.0;
    _monthlyDistance = 0.0;
    _lastDistanceUpdateStr = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_distanceKey);
    await prefs.remove('weeklyDistance');
    await prefs.remove('monthlyDistance');
    await prefs.remove('lastDistanceUpdate');
  }
}

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  LocationService._internal();

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
      // Ensure permissions are granted before trying to get position
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        final requested = await requestLocationPermission();
        if (!requested) return null;
      }

      // Try getting last known position first for instant response
      Position? position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        ).timeout(const Duration(seconds: 5));
      }
      return position;
    } catch (e) {
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

  /// Stream of positions for map tracking (polyline and marker)
  Stream<Position> get positionUpdateStream {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 10, // Update more frequently for map
      ),
    );
  }

  /// Get last known position
  Position? get lastPosition => _lastPosition;

  /// Reset tracking
  void reset() {
    _lastPosition = null;
  }
}

