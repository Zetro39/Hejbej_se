import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pedometer/pedometer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/location_service.dart';
import '../../services/auth_service.dart';
import 'package:pay/pay.dart';
import 'ar_navigation_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] as String? ?? '',
      placeId: json['place_id'] as String? ?? '',
    );
  }
}

/// Modul Mapy – Live GPS tracking s Google Maps.
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  late LocationService _locationService;
  late Stream<Position> _positionStream;
  StreamSubscription<Position>? _positionSubscription;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];
  final List<LatLng> _breadcrumbsCoordinates = [];

  BitmapDescriptor? _avatarIcon;
  bool _usingBike = false;
  double _walkRangeMin = 2.0;
  double _walkRangeMax = 5.0;
  double _bikeRangeMin = 10.0;
  double _bikeRangeMax = 30.0;
  final double _dailyTargetKm = 1.0;
  bool _routeActive = false;
  bool _isLoadingRoutes = false;
  bool _showRouteSuggestions = false;
  List<Map<String, dynamic>> _routeSuggestions = [];
  int _selectedRouteSuggestionIndex = 0;
  bool _showRouteSearch = false;
  late final PageController _routePageController;
  StreamSubscription<StepCount>? _stepCountSubscription;

  // Removed dummy Prague checkpoints left from testing.
  static const List<Map<String, dynamic>> _checkpoints = [];

  final Set<String> _reachedCheckpoints = {};
  double _todayDistance = 0.0;

  bool _isFollowingUser = true;
  Position? _lastPosition;
  Position? _initialPosition;
  Position? _previousPosition;

  double _totalDistance = 0.0;
  int _limetkyBalance = 0;
  int _streak = 0;
  DateTime? _lastActivityDate;
  bool _isStreakFrozen = false;

  static const String _googleApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: 'AIzaSyDxxxxxxxxxxxxxxxxxxxxxxxxx',
  );

  final TextEditingController _destinationController = TextEditingController();

  bool _isSelectingDestination = false;
  LatLng? _destinationPoint;

  // UI & routing control
  bool _taskCardExpanded = false;
  bool _trackingEnabled = false; // accumulate distance only when true
  bool _routePlotted = false; // route geometry present but not yet started

  List<PlacePrediction> _placePredictions = [];
  bool _showSuggestions = false;

  // Elevation & Rewards

  @override
  void initState() {
    super.initState();
    _routePageController = PageController(viewportFraction: 0.88);
    _locationService = LocationService();
    _positionStream = _locationService.positionUpdateStream;
    _loadSelectedAvatar();
    _loadReachedCheckpoints();
    _loadRangePreferences();
    _loadPersistentData();
    _setupMap();
    _initPedometer();
    _loadPremiumStatus();
  }

  Future<void> _loadReachedCheckpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final reached = <String>{};
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      if (prefs.getBool('achievement_${id}_reached') ?? false) {
        reached.add(id);
      }
    }
    if (mounted) {
      setState(() {
        _reachedCheckpoints.addAll(reached);
      });
    }
  }

  Future<void> _loadPersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    _totalDistance = prefs.getDouble('totalDistance') ?? 0.0;
    _limetkyBalance = prefs.getInt('limetkyBalance') ?? 0;
    _streak = prefs.getInt('streak') ?? 0;
    _isStreakFrozen = prefs.getBool('isStreakFrozen') ?? false;
    final lastActivityString = prefs.getString('lastActivityDate');
    if (lastActivityString != null) {
      _lastActivityDate = DateTime.tryParse(lastActivityString);
    }
  }

  Future<void> _savePersistentData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('totalDistance', _totalDistance);
    await prefs.setInt('limetkyBalance', _limetkyBalance);
    await prefs.setInt('streak', _streak);
    await prefs.setBool('isStreakFrozen', _isStreakFrozen);
    if (_lastActivityDate != null) {
      await prefs.setString('lastActivityDate', _lastActivityDate!.toIso8601String());
    }

    // Sync to Firestore
    await AuthService().updateDistance(_totalDistance, _limetkyBalance);
    await AuthService().updateStreak(_streak);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isConsecutiveDay(DateTime last, DateTime now) {
    final difference = now.difference(last).inDays;
    return difference == 1;
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('selected_avatar');
    if (!mounted) return;

    if (avatar != null) {
      await _createAvatarIcon(avatar);
    }
  }

  Future<void> _loadRangePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _walkRangeMin = prefs.getDouble('walk_range_min') ?? 2.0;
      _walkRangeMax = prefs.getDouble('walk_range_max') ?? 5.0;
      _bikeRangeMin = prefs.getDouble('bike_range_min') ?? 10.0;
      _bikeRangeMax = prefs.getDouble('bike_range_max') ?? 30.0;
      _usingBike = prefs.getBool('preferred_bike_mode') ?? false;
    });
  }

  void _initPedometer() {
    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen((event) {
        // Step tracking prepared for later use.
      }, onError: (error) {
        debugPrint('Pedometer error: $error');
      });
    } catch (e) {
      debugPrint('Pedometer initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _positionSubscription?.cancel();
    _destinationController.dispose();
    _routePageController.dispose();
    _stepCountSubscription?.cancel();
    super.dispose();
  }

  Future<void> _createAvatarIcon(String avatar) async {
    final imagePath = 'assets/images/$avatar.png';
    final bitmapDescriptor = await BitmapDescriptor.asset(createLocalImageConfiguration(context), imagePath);
    if (!mounted) return;
    setState(() {
      _avatarIcon = bitmapDescriptor;
    });
  }

  Future<void> _setupMap() async {
    final initialPosition = await _locationService.getCurrentLocation();
    if (initialPosition != null) {
      _initialPosition = initialPosition;
      if (mounted) {
        _polylineCoordinates.add(
          LatLng(initialPosition.latitude, initialPosition.longitude),
        );
        _addMarker(initialPosition);
        _updatePolyline();
      }
    }
    // Checkpoints list intentionally empty after cleanup
    _addAllCheckpointMarkers();
  }

  void _checkCheckpointProximity(Position userPosition) {
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      if (_reachedCheckpoints.contains(id)) continue;

      final checkpointPosition = checkpoint['position'] as LatLng;
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        checkpointPosition.latitude,
        checkpointPosition.longitude,
      );

      if (distance < 20.0) {
        setState(() {
          _reachedCheckpoints.add(id);
        });
        _saveCheckpointAchievement(id);
        _updateCheckpointMarker(id, reached: true);
        _triggerCheckpointCelebration();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${checkpoint['title']} dosažen! Úspěch odemčen!'),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.lime,
            ),
          );
        }
        _checkLevelUp();
      }
    }
  }

  void _triggerCheckpointCelebration() {
    HapticFeedback.mediumImpact();
  }

  void _checkLevelUp() {
    if (_checkpoints.isNotEmpty && _reachedCheckpoints.length == _checkpoints.length) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Všechny body dokončeny! Skvělá práce.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  LatLng _destinationFromDistanceBearing(LatLng start, double distanceKm, double bearingDegrees) {
    const earthRadiusKm = 6371.0;
    final bearing = bearingDegrees * pi / 180.0;
    final lat1 = start.latitude * pi / 180.0;
    final lon1 = start.longitude * pi / 180.0;
    final angularDistance = distanceKm / earthRadiusKm;

    final lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing));
    final lon2 = lon1 + atan2(
      sin(bearing) * sin(angularDistance) * cos(lat1),
      cos(angularDistance) - sin(lat1) * sin(lat2),
    );

    return LatLng(lat2 * 180.0 / pi, lon2 * 180.0 / pi);
  }

  double _calculateRouteLength(List<LatLng> points) {
    double distance = 0.0;
    for (int i = 1; i < points.length; i++) {
      distance += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return distance / 1000.0;
  }

  int _calculateRouteEta(double distanceKm) {
    final speedKmH = _usingBike ? 15.0 : 5.0;
    return max(1, (distanceKm / speedKmH * 60).round());
  }

  Future<List<LatLng>> _fetchRouteGeometryFromOSRM(List<LatLng> coordinates, String profile) async {
    if (coordinates.length < 2) return [];
    final coordString = coordinates.map((point) => '${point.longitude},${point.latitude}').join(';');
    final uri = Uri.https('router.project-osrm.org', '/route/v1/$profile/$coordString', {
      'overview': 'full',
      'geometries': 'geojson',
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['code'] == 'Ok' && body['routes'] is List && body['routes'].isNotEmpty) {
          final route = (body['routes'] as List<dynamic>)[0] as Map<String, dynamic>;
          final geometry = route['geometry'] as Map<String, dynamic>?;
          if (geometry != null && geometry['coordinates'] is List) {
            return (geometry['coordinates'] as List<dynamic>)
                .whereType<List<dynamic>>()
                .map((coord) => LatLng(
                      (coord[1] as num).toDouble(),
                      (coord[0] as num).toDouble(),
                    ))
                .toList();
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM route fetch error: $e');
    }
    return [];
  }

  Future<void> _selectRouteSuggestion(int index) async {
    if (index < 0 || index >= _routeSuggestions.length) return;
    final route = _routeSuggestions[index];
    final points = route['coordinates'] as List<LatLng>?;
    if (points == null || points.length < 2) return;

    final polyline = Polyline(
      polylineId: const PolylineId('active_route'),
      color: _usingBike ? Colors.blue : Colors.green,
      width: 5,
      points: points,
      geodesic: true,
    );

    setState(() {
      // plot route but don't start tracking until explicit START
      _routePlotted = true;
      _routeActive = false;
      _selectedRouteSuggestionIndex = index;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _polylines.add(polyline);
      _destinationPoint = points.last;
      _showRouteSuggestions = true;
      _taskCardExpanded = false; // collapse top card so map is more visible
    });

    await _fetchElevationData(points).catchError((_) {});
  }

  Future<void> _generateNearbyRoutes() async {
    if (_lastPosition == null) return;
    final start = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final profile = _usingBike ? 'bike' : 'foot';
    final minRange = _usingBike ? _bikeRangeMin : _walkRangeMin;
    final maxRange = _usingBike ? _bikeRangeMax : _walkRangeMax;
    setState(() {
      _isLoadingRoutes = true;
      _showRouteSuggestions = true;
      _routeSuggestions.clear();
      _routeActive = false;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _markers.removeWhere((m) => m.markerId.value.startsWith('route_'));
    });

    final routeNames = ['Lesní okruh', 'Říční cesta', 'Městský okruh', 'Zelená stezka', 'Vyhlídkový okruh'];
    final random = Random();
    final suggestions = <Map<String, dynamic>>[];

    for (int i = 0; i < 5; i++) {
      final distanceKm = minRange + random.nextDouble() * (maxRange - minRange);
      final bearing = random.nextDouble() * 360;
      // create two waypoints to form a true loop and avoid retracing
      final wp1 = _destinationFromDistanceBearing(start, distanceKm / 3, bearing - 45);
      final wp2 = _destinationFromDistanceBearing(start, distanceKm / 3, bearing + 45);
      final routePoints = await _fetchRouteGeometryFromOSRM([start, wp1, wp2, start], profile);
      if (routePoints.length < 2) continue;
      final actualDistance = _calculateRouteLength(routePoints);
      suggestions.add({
        'title': '${routeNames[i % routeNames.length]} ${actualDistance.toStringAsFixed(1)} km',
        'coordinates': routePoints,
        'distance': actualDistance,
        'eta': _calculateRouteEta(actualDistance),
        'poi_count': random.nextInt(3) + 1,
      });
      if (suggestions.length >= 4) break;
    }

    if (!mounted) return;
    setState(() {
      _routeSuggestions = suggestions;
      _selectedRouteSuggestionIndex = 0;
      _isLoadingRoutes = false;
    });

    if (_routeSuggestions.isNotEmpty) {
      await _selectRouteSuggestion(0);
    }
  }

  Future<void> _generateDestinationRoute(LatLng destination) async {
    if (_lastPosition == null) return;
    final start = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final profile = _usingBike ? 'bike' : 'foot';
    final routePoints = await _fetchRouteGeometryFromOSRM([start, destination], profile);
    if (routePoints.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nepodařilo se načíst trasu. Zkuste to znovu.')),
      );
      return;
    }

    final polyline = Polyline(
      polylineId: const PolylineId('active_route'),
      color: Colors.green,
      width: 5,
      points: routePoints,
      geodesic: true,
    );

    setState(() {
      // plot destination route but wait for explicit START
      _routePlotted = true;
      _routeActive = false;
      _destinationPoint = destination;
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _polylines.add(polyline);
      _showRouteSearch = false;
      _showRouteSuggestions = false;
      _routeSuggestions = [
        {
          'title': 'Cesta do cíle',
          'coordinates': routePoints,
          'distance': _calculateRouteLength(routePoints),
          'eta': _calculateRouteEta(_calculateRouteLength(routePoints)),
          'poi_count': 0,
        }
      ];
      _taskCardExpanded = false;
    });

    await _fetchElevationData(routePoints).catchError((_) {});
  }

  void _cancelRoute() {
    setState(() {
      _routeActive = false;
      _routePlotted = false;
      _trackingEnabled = false;
      _destinationPoint = null;
      _showRouteSearch = false;
      _showRouteSuggestions = false;
      _routeSuggestions.clear();
      _polylines.removeWhere((p) => p.polylineId.value == 'active_route');
      _markers.removeWhere((m) => m.markerId.value.startsWith('route_'));
    });
  }

  void _startRoute() {
    setState(() {
      _trackingEnabled = true;
      _routeActive = true;
      _routePlotted = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('START / VYRAZIT — trasa spuštěna')));
  }

  Widget _buildRouteInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.lightBlue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
      ),
    );
  }

  Future<void> _saveCheckpointAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_${id}_reached', true);
  }


  Future<void> _fetchElevationData(List<LatLng> routePoints) async {
    if (routePoints.isEmpty) return;

    try {
      final path = routePoints.map((p) => '${p.latitude},${p.longitude}').join('|');
      final uri = Uri.https('maps.googleapis.com', '/maps/api/elevation/json', {
        'locations': path,
        'key': _googleApiKey,
      });
      
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Elevation API timeout'),
      );
      
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['results'] is List) {
          final results = body['results'] as List<dynamic>;
          if (results.isNotEmpty) {
            double previousElevation = (results.first['elevation'] as num).toDouble();
            double elevationGain = 0.0;
            for (final result in results.skip(1)) {
              final elevation = (result['elevation'] as num).toDouble();
              if (elevation > previousElevation) {
                elevationGain += elevation - previousElevation;
              }
              previousElevation = elevation;
            }
            final extraLimetkas = (elevationGain / 10).floor();
            if (extraLimetkas > 0) {
              _limetkyBalance += extraLimetkas;
              await _savePersistentData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Bonus za převýšení: +$extraLimetkas Limetků!')),
                );
              }
            }
          }
        } else {
          debugPrint('Elevation API error: ${body['status']}');
        }
      } else {
        debugPrint('Elevation API HTTP error: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching elevation: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching elevation: $e');
    } catch (e) {
      debugPrint('Unexpected error fetching elevation: $e');
    }
  }


  Future<void> _fetchPlacePredictions(String input) async {
    if (input.isEmpty || input.trim().length < 2) {
      setState(() {
        _placePredictions = [];
        _showSuggestions = false;
      });
      return;
    }

    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
        'input': input,
        'components': 'country:cz',
        'language': 'cs',
        'key': _googleApiKey,
      });
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Place Autocomplete API timeout'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['predictions'] is List) {
          setState(() {
            _placePredictions = (body['predictions'] as List<dynamic>)
                .whereType<Map<String, dynamic>>()
                .map(PlacePrediction.fromJson)
                .toList();
            _showSuggestions = true;
          });
          return;
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching place predictions: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching place predictions: $e');
    } catch (e) {
      debugPrint('Place Autocomplete API error: $e');
    }

    setState(() {
      _placePredictions = [];
      _showSuggestions = false;
    });
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
        'place_id': prediction.placeId,
        'fields': 'formatted_address,geometry',
        'language': 'cs',
        'key': _googleApiKey,
      });
      final response = await http.get(uri).timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw Exception('Place Details API timeout'),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['status'] == 'OK' && body['result'] is Map<String, dynamic>) {
          final place = body['result'] as Map<String, dynamic>;
          final geometry = place['geometry'] as Map<String, dynamic>?;
          final location = geometry?['location'] as Map<String, dynamic>?;
          if (location != null) {
            final lat = (location['lat'] as num).toDouble();
            final lng = (location['lng'] as num).toDouble();
            final latLng = LatLng(lat, lng);
            if (!mounted) return;
            setState(() {
              _destinationController.text = place['formatted_address'] as String? ?? prediction.description;
              _showSuggestions = false;
              _showRouteSearch = false;
            });
            _generateDestinationRoute(latLng);
            FocusScope.of(context).unfocus();
            return;
          }
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching place details: $e');
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching place details: $e');
    } catch (e) {
      debugPrint('Place Details API error: $e');
    }
  }

  Future<void> _snapBreadcrumbsToRoads() async {
    if (_breadcrumbsCoordinates.length < 2) return;

    try {
      final path = _breadcrumbsCoordinates
          .map((p) => '${p.latitude},${p.longitude}')
          .join('|');
      final uri = Uri.https('roads.googleapis.com', '/v1/snapToRoads', {
        'path': path,
        'interpolate': 'true',
        'key': _googleApiKey,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['snappedPoints'] is List) {
          final snappedPoints = (body['snappedPoints'] as List<dynamic>)
              .map((point) {
                final location = point['location'] as Map<String, dynamic>;
                return LatLng(
                  (location['latitude'] as num).toDouble(),
                  (location['longitude'] as num).toDouble(),
                );
              })
              .toList();
          if (snappedPoints.isNotEmpty && mounted) {
            setState(() {
              _breadcrumbsCoordinates
                ..clear()
                ..addAll(snappedPoints);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Snap to Roads API error: $e');
    }
  }

  void _updateCheckpointMarker(String checkpointId, {required bool reached}) {
    final markerId = MarkerId(checkpointId);
    final existingMarker = _markers.firstWhere(
      (marker) => marker.markerId == markerId,
      orElse: () => const Marker(markerId: MarkerId('')),
    );

    if (existingMarker.markerId.value.isNotEmpty) {
      final updatedMarker = existingMarker.copyWith(
        iconParam: reached
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      );
      setState(() {
        _markers.removeWhere((marker) => marker.markerId == markerId);
        _markers.add(updatedMarker);
      });
    }
  }

  void _addAllCheckpointMarkers() {
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      final position = checkpoint['position'] as LatLng;
      final title = checkpoint['title'] as String;
      final isReached = _reachedCheckpoints.contains(id);
      final marker = Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: isReached
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      );
      setState(() {
        _markers.add(marker);
      });
    }
  }

  void _addMarker(Position position) {
    final userMarkerId = const MarkerId('user_location');
    final userPosition = LatLng(position.latitude, position.longitude);
    final marker = Marker(
      markerId: userMarkerId,
      position: userPosition,
      rotation: position.heading,
      anchor: const Offset(0.5, 0.5),
      icon: _avatarIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: const InfoWindow(title: 'Vaše poloha'),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId == userMarkerId);
      _markers.add(marker);
    });
  }

  double _calculatePolylineDistance() {
    double totalDistance = 0.0;
    for (int i = 1; i < _polylineCoordinates.length; i++) {
      totalDistance += Geolocator.distanceBetween(
        _polylineCoordinates[i - 1].latitude,
        _polylineCoordinates[i - 1].longitude,
        _polylineCoordinates[i].latitude,
        _polylineCoordinates[i].longitude,
      );
    }
    return totalDistance;
  }

  void _updatePolyline() {
    if (_polylineCoordinates.length < 2) return;
    const polylineId = PolylineId('user_path');
    final polyline = Polyline(
      polylineId: polylineId,
      color: Colors.lime,
      width: 5,
      points: _polylineCoordinates,
      geodesic: true,
    );
    setState(() {
      _polylines.removeWhere((p) => p.polylineId == polylineId);
      _polylines.add(polyline);
    });
  }

  void _updateBreadcrumbsPolyline() {
    if (_breadcrumbsCoordinates.length < 2) return;
    const polylineId = PolylineId('breadcrumbs');
    final polyline = Polyline(
      polylineId: polylineId,
      color: const Color(0xFFBFFF00),
      width: 3,
      points: _breadcrumbsCoordinates,
      geodesic: true,
    );
    setState(() {
      _polylines.removeWhere((p) => p.polylineId == polylineId);
      _polylines.add(polyline);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // If we already obtained an initial location, center the camera immediately
    if (_initialPosition != null) {
      try {
        final cameraPosition = CameraPosition(
          target: LatLng(_initialPosition!.latitude, _initialPosition!.longitude),
          zoom: 16.0,
        );
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
      } catch (_) {}
    }

    _positionSubscription = _positionStream.listen((position) async {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);

      // Update streak
      final today = DateTime.now();
      if (_lastActivityDate == null || !_isSameDay(_lastActivityDate!, today)) {
        if (_lastActivityDate != null && _isConsecutiveDay(_lastActivityDate!, today)) {
          _streak++;
        } else if (_lastActivityDate == null) {
          _streak = 1;
        } else {
          if (!_isStreakFrozen) {
            _streak = 1;
          }
        }
        _lastActivityDate = today;
        await _savePersistentData();
      }

      // Update distance only when tracking is enabled
      if (_previousPosition != null && _trackingEnabled) {
        final distanceKm = Geolocator.distanceBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        ) / 1000.0;
        _totalDistance += distanceKm;
        _limetkyBalance += distanceKm.toInt();
        await _savePersistentData();
      }
      _previousPosition = position;

      if (_breadcrumbsCoordinates.isEmpty ||
          Geolocator.distanceBetween(
            _breadcrumbsCoordinates.last.latitude,
            _breadcrumbsCoordinates.last.longitude,
            newPoint.latitude,
            newPoint.longitude,
          ) > 10.0) {
        setState(() {
          _breadcrumbsCoordinates.add(newPoint);
        });
        _snapBreadcrumbsToRoads();
        _updateBreadcrumbsPolyline();
      }
      if (_polylineCoordinates.isEmpty ||
          _polylineCoordinates.last.latitude != newPoint.latitude ||
          _polylineCoordinates.last.longitude != newPoint.longitude) {
        setState(() {
          _polylineCoordinates.add(newPoint);
        });
        _updatePolyline();
      }
      _addMarker(position);
      _checkCheckpointProximity(position);
      setState(() {
        _todayDistance = _calculatePolylineDistance();
        _lastPosition = position;
      });
      if (_isFollowingUser) {
        double baseZoom = 16.0;
        if (position.speed > 0) {
          final speedFactor = position.speed.clamp(0.0, 5.0) / 5.0;
          baseZoom = 16.0 - (speedFactor * 2.0);
        }
        final cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: baseZoom,
          bearing: position.heading,
          tilt: 0.0,
        );
        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(cameraPosition),
        );
      }
    });
  }

  void _showLongPressMenu(BuildContext context, LatLng latLng) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Akce na místě',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.place, color: Color(0xFFBFFF00)),
              title: const Text('Nahlásit POI'),
              subtitle: const Text('Označit zajímavé místo'),
              onTap: () {
                Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('POI nahlášeno!')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions, color: Color(0xFFBFFF00)),
              title: const Text('Nastavit cíl'),
              subtitle: const Text('Vytvořit trasu do tohoto místa'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _destinationPoint = latLng;
                  _showRouteSearch = false;
                  _generateDestinationRoute(latLng);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNavigationMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Vyberte režim mapy',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.lightBlue.shade50,
                  child: const Icon(Icons.loop, color: Colors.lightBlue),
                ),
                title: const Text('Okruh v okolí'),
                subtitle: const Text('Najděte snadné okruhy start-cíl ve vašem dosahu'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showRouteSearch = false;
                    _showRouteSuggestions = true;
                    _isSelectingDestination = false;
                  });
                  _generateNearbyRoutes();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.lightBlue.shade50,
                  child: const Icon(Icons.location_pin, color: Colors.lightBlue),
                ),
                title: const Text('Cesta do cíle'),
                subtitle: const Text('Zadejte cíl a nechte trasu vytvořit'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showRouteSearch = false;
                    _showRouteSuggestions = false;
                    _isSelectingDestination = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Klikněte na mapu pro výběr cíle.')),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.lightBlue.shade50,
                  child: const Icon(Icons.search, color: Colors.lightBlue),
                ),
                title: const Text('Hledat destinaci'),
                subtitle: const Text('Vyhledejte město nebo cíl ve vyhledávání'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showRouteSearch = true;
                    _showRouteSuggestions = false;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomOffset = MediaQuery.of(context).padding.bottom + 80;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                onCameraMoveStarted: () {
                  setState(() {
                    _isFollowingUser = false;
                  });
                },
                onTap: (latLng) {
                  if (_isSelectingDestination) {
                    setState(() {
                      _isSelectingDestination = false;
                      _destinationPoint = latLng;
                      _generateDestinationRoute(latLng);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cíl zvolen. Trasa vytvořena.')),
                    );
                  }
                },
                onLongPress: (latLng) {
                  _showLongPressMenu(context, latLng);
                },
                initialCameraPosition: const CameraPosition(
                  target: LatLng(50.0755, 14.4378),
                  zoom: 13,
                ),
                polylines: _polylines,
                markers: _markers,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                padding: const EdgeInsets.only(top: 150, right: 16),
                compassEnabled: true,
                zoomControlsEnabled: true,
              ),
            ),
          ),
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _taskCardExpanded = !_taskCardExpanded),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: _taskCardExpanded ? 160 : 72,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.directions_walk, color: Colors.lightBlue, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Úkol: Ujdi 1 km dnes',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _todayDistance >= _dailyTargetKm * 1000 ? Colors.green : Colors.lightBlue.shade50,
                              child: Icon(_todayDistance >= _dailyTargetKm * 1000 ? Icons.check : Icons.timer, color: _todayDistance >= _dailyTargetKm * 1000 ? Colors.white : Colors.lightBlue),
                            ),
                            const SizedBox(width: 8),
                            Icon(_taskCardExpanded ? Icons.expand_less : Icons.expand_more),
                          ],
                        ),
                        if (_taskCardExpanded) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: min(_todayDistance / 1000.0 / _dailyTargetKm, 1.0),
                              minHeight: 10,
                              backgroundColor: Colors.lightBlue.shade50,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showNavigationMenu,
                              icon: const Icon(Icons.menu),
                              label: const Text('Výběr trasy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFBFFF00),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isSelectingDestination)
            Positioned(
              top: topPadding + 210,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.lightBlue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Klikněte na mapu pro výběr cíle, nebo zrušte a vyhledejte destinaci.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSelectingDestination = false;
                          });
                        },
                        child: const Text('Zrušit'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_routeActive)
            Positioned(
              top: topPadding + 154,
              right: 20,
              child: CircleAvatar(
                backgroundColor: const Color.fromRGBO(255, 255, 255, 0.9),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: _cancelRoute,
                ),
              ),
            ),
          Positioned(
            top: topPadding + 140,
            left: 16,
            right: 16,
            child: AnimatedOpacity(
              opacity: _routeActive || _showRouteSearch || _routePlotted ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !(_routeActive || _showRouteSearch || _routePlotted),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_destinationPoint != null) ...[
                          const Text(
                            'Na trase do cíle',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Vzdálenost se přičte až po fyzické chůzi',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if ((_routeActive || _routePlotted) && _routeSuggestions.isNotEmpty) ...[
                          Text(
                            _routeSuggestions[_selectedRouteSuggestionIndex]['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              _buildRouteInfoChip('${(_routeSuggestions[_selectedRouteSuggestionIndex]['distance'] as double).toStringAsFixed(1)} km'),
                              _buildRouteInfoChip('${_routeSuggestions[_selectedRouteSuggestionIndex]['eta']} min'),
                              _buildRouteInfoChip('${_routeSuggestions[_selectedRouteSuggestionIndex]['poi_count']} POI'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_routePlotted && !_trackingEnabled)
                            ElevatedButton(
                              onPressed: _startRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('START / VYRAZIT', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showRouteSearch)
            Positioned(
              bottom: bottomOffset + 220,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Hledat destinaci',
                          hintText: 'Například Pardubice',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: _fetchPlacePredictions,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showRouteSearch = false;
                                _showRouteSuggestions = false;
                                _isSelectingDestination = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Klikněte na mapu pro výběr cíle.')),
                              );
                            },
                            child: const Text('Vybrat na mapě'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showRouteSearch = false;
                                _showRouteSuggestions = false;
                                _isSelectingDestination = false;
                              });
                            },
                            child: const Text('Zrušit'),
                          ),
                        ],
                      ),
                      if (_showSuggestions && _placePredictions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          itemCount: _placePredictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _placePredictions[index];
                            return ListTile(
                              title: Text(prediction.description),
                              onTap: () => _selectPlace(prediction),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_showRouteSuggestions)
            Positioned(
              bottom: bottomOffset + 120,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 180,
                child: _isLoadingRoutes
                    ? Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 8,
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : PageView.builder(
                        controller: _routePageController,
                        onPageChanged: (index) {
                          _selectRouteSuggestion(index);
                        },
                        itemCount: _routeSuggestions.length,
                        itemBuilder: (context, index) {
                          final route = _routeSuggestions[index];
                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 8,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route['title'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 10),
                                  Text('Vzdálenost: ${(route['distance'] as double).toStringAsFixed(1)} km'),
                                  Text('Čas: ${route['eta']} min'),
                                  Text('POI: ${route['poi_count']}'),
                                  const Spacer(),
                                  ElevatedButton(
                                    onPressed: () => _selectRouteSuggestion(index),
                                    style: const ButtonStyle(
                                      backgroundColor: WidgetStatePropertyAll(Colors.lightBlue),
                                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                                    ),
                                    child: const Text('Vybrat trasu'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          Positioned(
            bottom: bottomOffset,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _showNavigationMenu,
              icon: const Icon(Icons.menu),
              label: const Text('Výběr trasy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBFFF00),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          Positioned(
            bottom: bottomOffset + 76,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'ar_nav_button',
              onPressed: _onArPressed,
              backgroundColor: const Color(0xFFBFFF00),
              foregroundColor: Colors.black,
              child: const Icon(Icons.remove_red_eye, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  // Premium & AR Methods
  bool _isPremium = false;

  Future<void> _loadPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isPremium = prefs.getBool('isPremium') ?? false;
      });
    }
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = doc.data() ?? {};
        final isPremiumDb = data['isPremium'] as bool? ?? false;
        if (isPremiumDb != _isPremium && mounted) {
          setState(() {
            _isPremium = isPremiumDb;
          });
          await prefs.setBool('isPremium', isPremiumDb);
        }
      }
    } catch (_) {}
  }

  void _onArPressed() {
    if (_polylineCoordinates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nejprve vyberte nebo zapněte trasu na mapě.')),
      );
      return;
    }

    if (_isPremium) {
      _openArNavigation();
    } else {
      _showPaywall();
    }
  }

  void _openArNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ArNavigationScreen(routePoints: _polylineCoordinates),
      ),
    );
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.stars, size: 72, color: Colors.amber),
              const SizedBox(height: 16),
              const Text(
                'Aktivujte Hejbej se Premium!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Získejte přístup k AR Navigaci přímo na silnici! Uvidíte trasu vykreslenou v rozšířené realitě přímo před sebou.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.lime.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.lime),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Měsíční předplatné',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      '25 Kč / měsíc',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.lightBlue),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              if (Platform.isAndroid)
                GooglePayButton(
                  paymentConfiguration: PaymentConfiguration.fromJsonString(
                    r'''{
                      "provider": "google_pay",
                      "data": {
                        "environment": "TEST",
                        "apiVersion": 2,
                        "apiVersionMinor": 0,
                        "allowedPaymentMethods": [
                          {
                            "type": "CARD",
                            "tokenizationSpecification": {
                              "type": "PAYMENT_GATEWAY",
                              "parameters": {
                                "gateway": "example",
                                "gatewayMerchantId": "exampleGatewayMerchantId"
                              }
                            },
                            "parameters": {
                              "allowedAuthMethods": ["PAN_ONLY", "CRYPTOGRAM_3DS"],
                              "allowedCardNetworks": ["AMEX", "DISCOVER", "JCB", "MASTERCARD", "VISA"]
                            }
                          }
                        ],
                        "merchantInfo": {
                          "merchantName": "Hejbej se"
                        },
                        "transactionInfo": {
                          "countryCode": "CZ",
                          "currencyCode": "CZK",
                          "totalPriceStatus": "FINAL",
                          "totalPrice": "25.00"
                        }
                      }
                    }'''
                  ),
                  paymentItems: const [
                    PaymentItem(
                      label: 'Hejbej se Premium',
                      amount: '25.00',
                      status: PaymentItemStatus.final_price,
                    )
                  ],
                  type: GooglePayButtonType.subscribe,
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(top: 8.0),
                  onPaymentResult: (result) => _unlockPremium(),
                  loadingIndicator: const Center(child: CircularProgressIndicator()),
                )
              else if (Platform.isIOS)
                ApplePayButton(
                  paymentConfiguration: PaymentConfiguration.fromJsonString(
                    r'''{
                      "provider": "apple_pay",
                      "data": {
                        "merchantIdentifier": "merchant.com.zetro39.hejbejse",
                        "supportedNetworks": ["visa", "masterCard", "amex"],
                        "countryCode": "CZ",
                        "currencyCode": "CZK"
                      }
                    }'''
                  ),
                  paymentItems: const [
                    PaymentItem(
                      label: 'Hejbej se Premium',
                      amount: '25.00',
                      status: PaymentItemStatus.final_price,
                    )
                  ],
                  style: ApplePayButtonStyle.black,
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(top: 8.0),
                  onPaymentResult: (result) => _unlockPremium(),
                ),
              
              const SizedBox(height: 12),
              
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _unlockPremium();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.lime, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  '[Test Bypass] Odemknout zdarma',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _unlockPremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': true,
      }, SetOptions(merge: true));
    }
    
    setState(() {
      _isPremium = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Premium aktivováno! Nyní můžete používat AR navigaci.'),
          backgroundColor: Colors.green,
        ),
      );
      
      if (_polylineCoordinates.isNotEmpty) {
        _openArNavigation();
      }
    }
  }
}
