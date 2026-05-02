import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

import '../../services/location_service.dart';

/// Modul Mapy – Live GPS tracking s Google Maps.
class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
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
      });

      // Animate camera to follow user
      if (_polylineCoordinates.isNotEmpty) {
        double minLat = _polylineCoordinates.first.latitude;
        double maxLat = _polylineCoordinates.first.latitude;
        double minLng = _polylineCoordinates.first.longitude;
        double maxLng = _polylineCoordinates.first.longitude;

        for (final point in _polylineCoordinates) {
          minLat = minLat > point.latitude ? point.latitude : minLat;
          maxLat = maxLat < point.latitude ? point.latitude : maxLat;
          minLng = minLng > point.longitude ? point.longitude : minLng;
          maxLng = maxLng < point.longitude ? point.longitude : maxLng;
        }

        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            50.0,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live mapa'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            onMapCreated: _onMapCreated,
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
          // Top overlay with task
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
          // Distance tracker overlay
          Positioned(
            top: 80,
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
          // Bottom button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hledání parků v okolí...'),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.radar,
                  size: 28,
                ),
                label: const Text(
                  'SKENOVAT OKOLÍ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.lime),
                  foregroundColor: WidgetStateProperty.all(Colors.black),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
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
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
}

