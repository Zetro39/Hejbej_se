import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Checkpoint coordinates (approximately 200m NE from Prague center)
  static const LatLng _checkpointPosition = LatLng(50.0773, 14.4403);
  bool _checkpointReached = false;

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _positionStream = _locationService.positionUpdateStream;
    _loadSelectedAvatar();
    _setupMap();
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

    // Add checkpoint marker
    _addCheckpointMarker();
  }

  void _checkCheckpointProximity(Position position) {
    if (_checkpointReached) return;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _checkpointPosition.latitude,
      _checkpointPosition.longitude,
    );

    if (distance < 20.0) { // 20 meters
      setState(() {
        _checkpointReached = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Cíl dosažen! Úspěch odemčen!'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.lime,
        ),
      );

      // Here you could also trigger additional achievements or rewards
      // For now, we'll just mark it as reached
    }
  }

  void _updatePolyline() {
    if (_polylineCoordinates.length < 2) return;

    const polylineId = PolylineId('user_path');
    final polyline = Polyline(
      polylineId: polylineId,
      color: Colors.blue,
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

