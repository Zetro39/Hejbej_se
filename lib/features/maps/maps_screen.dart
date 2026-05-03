import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import '../../services/location_service.dart';

/// Modul Mapy – Live GPS tracking s Google Maps.
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with TickerProviderStateMixin {
  late GoogleMapController _mapController;
  late LocationService _locationService;
  late Stream<Position> _positionStream;

  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  final List<LatLng> _polylineCoordinates = [];

  String? _selectedAvatar;
  BitmapDescriptor? _avatarIcon;

  // Multiple checkpoint coordinates around Prague
  static const List<Map<String, dynamic>> _checkpoints = [
    {
      'id': 'checkpoint_1',
      'position': LatLng(50.0773, 14.4403), // NE direction
      'title': 'Severovýchodní checkpoint',
    },
    {
      'id': 'checkpoint_2', 
      'position': LatLng(50.0727, 14.4403), // SE direction
      'title': 'Jižovýchodní checkpoint',
    },
    {
      'id': 'checkpoint_3',
      'position': LatLng(50.0727, 14.4297), // SW direction  
      'title': 'Jihozápadní checkpoint',
    },
    {
      'id': 'checkpoint_4',
      'position': LatLng(50.0773, 14.4297), // NW direction
      'title': 'Severozápadní checkpoint',
    },
    {
      'id': 'checkpoint_5',
      'position': LatLng(50.0755, 14.4450), // East direction
      'title': 'Východní checkpoint',
    },
  ];

  final Set<String> _reachedCheckpoints = {};
  double _todayDistance = 0.0;

  // Animation and celebration
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showCelebration = false;

  // Camera control
  bool _isFollowingUser = true;
  Position? _lastPosition;

  // Trip generation
  bool _showTripOptions = false;
  double _selectedDistance = 5.0; // km
  bool _isGeneratingTrip = false;
  List<Map<String, dynamic>> _tripPoints = [];

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _positionStream = _locationService.positionUpdateStream;
    _loadSelectedAvatar();
    _loadReachedCheckpoints();
    _setupMap();

    // Initialize animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );
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
    setState(() {
      _reachedCheckpoints.addAll(reached);
    });
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('selected_avatar');
    setState(() {
      _selectedAvatar = avatar;
    });

    if (avatar != null) {
      await _createAvatarIcon(avatar);
    }
  }

  Future<void> _createAvatarIcon(String avatar) async {
    final imagePath = 'assets/images/$avatar.png';
    final bitmapDescriptor = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      imagePath,
    );
    setState(() {
      _avatarIcon = bitmapDescriptor;
    });
  }

  Future<void> _setupMap() async {
    // Get initial position
    final initialPosition = await _locationService.getCurrentLocation();
    if (initialPosition != null && mounted) {
      _polylineCoordinates.add(
        LatLng(initialPosition.latitude, initialPosition.longitude),
      );
      _addMarker(initialPosition);
      _updatePolyline();
    }

    // Add all checkpoint markers
    _addAllCheckpointMarkers();
  }

  void _checkCheckpointProximity(Position userPosition) {
    for (final checkpoint in _checkpoints) {
      final id = checkpoint['id'] as String;
      if (_reachedCheckpoints.contains(id)) continue; // Already reached

      final checkpointPosition = checkpoint['position'] as LatLng;
      final distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        checkpointPosition.latitude,
        checkpointPosition.longitude,
      );

      if (distance < 20.0) { // 20 meters
        setState(() {
          _reachedCheckpoints.add(id);
        });

        // Save achievement permanently
        _saveCheckpointAchievement(id);

        // Update marker color to green
        _updateCheckpointMarker(id, reached: true);

        // Trigger celebration effects
        _triggerCheckpointCelebration();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${checkpoint['title']} dosažen! Úspěch odemčen!'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.lime,
          ),
        );

        // Check for level up (all checkpoints reached)
        _checkLevelUp();
      }
    }
  }

  void _triggerCheckpointCelebration() {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Pulse animation for distance card
    _pulseController.forward(from: 0.0);
  }

  void _checkLevelUp() {
    if (_reachedCheckpoints.length == _checkpoints.length && !_showCelebration) {
      setState(() {
        _showCelebration = true;
      });

      // Hide celebration after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showCelebration = false;
          });
        }
      });
    }
  }

  Future<void> _saveCheckpointAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_${id}_reached', true);
  }

  void _recenterCamera() {
    if (_lastPosition != null) {
      setState(() {
        _isFollowingUser = true;
      });

      // Immediately snap to user's position with current bearing
      final cameraPosition = CameraPosition(
        target: LatLng(_lastPosition!.latitude, _lastPosition!.longitude),
        zoom: 16.0,
        bearing: _lastPosition!.heading,
        tilt: 0.0,
      );

      _mapController.animateCamera(
        CameraUpdate.newCameraPosition(cameraPosition),
      );
    }
  }

  void _generateTripLoop() {
    if (_lastPosition == null) return;

    setState(() {
      _isGeneratingTrip = true;
      _tripPoints.clear();
    });

    // Remove existing trip polylines and markers
    _polylines.removeWhere((p) => p.polylineId.value.startsWith('trip_'));
    _markers.removeWhere((m) => m.markerId.value.startsWith('trip_'));

    // Generate random closed loop around user position
    final center = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final radiusKm = _selectedDistance / 2; // Convert to radius

    final tripPoints = <LatLng>[];
    const numPoints = 8; // Points for the loop

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * 3.14159;
      final latOffset = (radiusKm / 111.32) * 0.7 * (0.5 + 0.5 * (i % 2 == 0 ? 1 : -1)); // ~111km per degree latitude
      final lngOffset = (radiusKm / (111.32 * cos(center.latitude * 3.14159 / 180))) * 0.7 * (0.5 + 0.5 * (i % 3 == 0 ? 1 : -1));

      tripPoints.add(LatLng(
        center.latitude + latOffset,
        center.longitude + lngOffset,
      ));
    }

    // Close the loop
    tripPoints.add(tripPoints.first);

    // Replace the user's polyline coordinates with the new trip loop so it displays
    _polylineCoordinates.clear();
    _polylineCoordinates.addAll(tripPoints);
    _updatePolyline();

    // Add trip polyline
    final tripPolyline = Polyline(
      polylineId: const PolylineId('trip_loop'),
      color: Colors.blue,
      width: 4,
      points: tripPoints,
      geodesic: true,
    );

    // Generate 3-4 random POI markers along the path
    final poiNames = ['Zřícenina', 'Vyhlídka', 'Park', 'Jezero'];
    final tripMarkers = <Marker>[];

    for (int i = 0; i < 4 && i < tripPoints.length - 1; i++) {
      final pointIndex = (i * tripPoints.length ~/ 4).clamp(0, tripPoints.length - 2);
      final point = tripPoints[pointIndex];

      tripMarkers.add(Marker(
        markerId: MarkerId('trip_poi_$i'),
        position: point,
        infoWindow: InfoWindow(title: poiNames[i]),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ));

      _tripPoints.add({
        'name': poiNames[i],
        'position': point,
      });
    }

    setState(() {
      _polylines.add(tripPolyline);
      _markers.addAll(tripMarkers);
      _isGeneratingTrip = false;
    });
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Listen to position updates
    _positionStream.listen((position) {
      if (!mounted) return;

      final newPoint = LatLng(position.latitude, position.longitude);

      // Add to polyline if far enough from last point
      if (_polylineCoordinates.isEmpty ||
          _polylineCoordinates.last.latitude != newPoint.latitude ||
          _polylineCoordinates.last.longitude != newPoint.longitude) {
        setState(() {
          _polylineCoordinates.add(newPoint);
        });
        _updatePolyline();
      }

      // Update marker
      _addMarker(position);

      // Check checkpoint proximity
      _checkCheckpointProximity(position);

      // Update today's distance
      setState(() {
        _todayDistance = _calculatePolylineDistance();
        _lastPosition = position;
      });

      // Smart camera following with bearing and speed-based zoom
      if (_isFollowingUser) {
        // Calculate zoom based on speed (zoom in when slow/stationary, zoom out when fast)
        double baseZoom = 16.0; // Default zoom level
        if (position.speed > 0) {
          // Speed is in m/s, adjust zoom inversely with speed
          // Zoom out when moving fast (up to 2x zoom out), zoom in when slow
          double speedFactor = position.speed.clamp(0.0, 5.0) / 5.0; // Normalize 0-5 m/s
          baseZoom = 16.0 - (speedFactor * 2.0); // 16.0 to 14.0 zoom range
        }

        // Create camera position with bearing (heading) for auto-rotation
        final cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: baseZoom,
          bearing: position.heading, // Auto-rotate map to face walking direction
          tilt: 0.0,
        );

        _mapController.animateCamera(
          CameraUpdate.newCameraPosition(cameraPosition),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              onCameraMoveStarted: () {
                // User started moving camera manually, disable auto-follow
                setState(() {
                  _isFollowingUser = false;
                });
              },
              initialCameraPosition: const CameraPosition(
                target: LatLng(50.0755, 14.4378), // Prague
                zoom: 13,
              ),
              polylines: _polylines,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              compassEnabled: true,
              zoomControlsEnabled: true,
            ),
          ),
        ),
          // Top overlay with task
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: true,
              bottom: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.lightBlue.shade200,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.task_alt,
                      color: Colors.lightBlue,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Úkol: Najdi nejbližší park',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.lightBlue.shade900,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Distance tracker overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 16,
            child: ScaleTransition(
              scale: _pulseAnimation,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                color: Colors.white.withOpacity(0.95),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_walk,
                        color: Colors.lime.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Dnešní vzdálenost',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_todayDistance.toStringAsFixed(0)} m',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.lime.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Trip generator button
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Main button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTripOptions = !_showTripOptions;
                        });
                      },
                      icon: const Icon(Icons.explore),
                      label: const Text(
                        'Okruh v okolí',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.limeAccent),
                        foregroundColor: WidgetStateProperty.all(Colors.black),
                        elevation: WidgetStateProperty.all(0),
                        shape: WidgetStateProperty.all(
                          const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dropdown button
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.limeAccent,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        // Handle dropdown selection
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Vybráno: $value')),
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'loop',
                          child: Text('Okruh v okolí (A → A)'),
                        ),
                        const PopupMenuItem(
                          value: 'destination',
                          child: Text('Cesta do cíle (A → B)'),
                        ),
                      ],
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.black,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Distance slider (when showing trip options)
          if (_showTripOptions)
            Positioned(
              bottom: 170,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vyberte délku okruhu: ${_selectedDistance.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Slider(
                        value: _selectedDistance,
                        min: 2.0,
                        max: 20.0,
                        divisions: 18,
                        label: '${_selectedDistance.toStringAsFixed(1)} km',
                        onChanged: (value) {
                          setState(() {
                            _selectedDistance = value;
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showTripOptions = false;
                              });
                            },
                            child: const Text('Zrušit'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showTripOptions = false;
                              });
                              _generateTripLoop();
                            },
                            child: const Text('Generovat'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Trip points card
          if (_tripPoints.isNotEmpty)
            Positioned(
              bottom: 180,
              left: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Body na trase:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._tripPoints.map((point) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.place,
                              size: 16,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              point['name'] as String,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          // Celebration overlay
          if (_showCelebration)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events,
                        size: 100,
                        color: Colors.yellow.shade600,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'LEVEL UP!',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Dokončil jsi všechny checkpointy!',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

