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
  final List<LatLng> _breadcrumbsCoordinates = [];

  String? _selectedAvatar;
  BitmapDescriptor? _avatarIcon;

  static const List<Map<String, dynamic>> _checkpoints = [
    {
      'id': 'checkpoint_1',
      'position': LatLng(50.0773, 14.4403),
      'title': 'Severovýchodní checkpoint',
    },
    {
      'id': 'checkpoint_2',
      'position': LatLng(50.0727, 14.4403),
      'title': 'Jižovýchodní checkpoint',
    },
    {
      'id': 'checkpoint_3',
      'position': LatLng(50.0727, 14.4297),
      'title': 'Jihozápadní checkpoint',
    },
    {
      'id': 'checkpoint_4',
      'position': LatLng(50.0773, 14.4297),
      'title': 'Severozápadní checkpoint',
    },
    {
      'id': 'checkpoint_5',
      'position': LatLng(50.0755, 14.4450),
      'title': 'Východní checkpoint',
    },
  ];

  final Set<String> _reachedCheckpoints = {};
  double _todayDistance = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showCelebration = false;

  bool _isFollowingUser = true;
  Position? _lastPosition;

  final TextEditingController _destinationController = TextEditingController();
  bool _showDestinationSearch = false;

  bool _showTripOptions = false;
  double _selectedDistance = 5.0;
  bool _isSelectingDestination = false;
  LatLng? _destinationPoint;
  List<Map<String, dynamic>> _tripPoints = [];
  String _tripMode = 'loop';

  @override
  void initState() {
    super.initState();
    _locationService = LocationService();
    _positionStream = _locationService.positionUpdateStream;
    _loadSelectedAvatar();
    _loadReachedCheckpoints();
    _setupMap();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _pulseController.dispose();
    _destinationController.dispose();
    super.dispose();
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

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('selected_avatar');
    if (!mounted) return;

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
    if (!mounted) return;
    setState(() {
      _avatarIcon = bitmapDescriptor;
    });
  }

  Future<void> _setupMap() async {
    final initialPosition = await _locationService.getCurrentLocation();
    if (initialPosition != null && mounted) {
      _polylineCoordinates.add(
        LatLng(initialPosition.latitude, initialPosition.longitude),
      );
      _addMarker(initialPosition);
      _updatePolyline();
    }
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
    _pulseController.forward(from: 0.0);
  }

  void _checkLevelUp() {
    if (_reachedCheckpoints.length == _checkpoints.length && !_showCelebration) {
      if (!mounted) return;
      setState(() {
        _showCelebration = true;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() {
          _showCelebration = false;
        });
      });
    }
  }

  Future<void> _saveCheckpointAchievement(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('achievement_${id}_reached', true);
  }

  void _recenterCamera() {
    if (_lastPosition == null) return;
    setState(() {
      _isFollowingUser = true;
    });
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

  void _generateTripLoop() {
    if (_lastPosition == null) return;

    setState(() {
      _showTripOptions = true;
      _isSelectingDestination = false;
      _tripPoints.clear();
    });

    _polylines.removeWhere((p) => p.polylineId.value.startsWith('trip_'));
    _markers.removeWhere((m) => m.markerId.value.startsWith('trip_'));
    _markers.removeWhere((m) => m.markerId.value == 'trip_dest');

    final center = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final radiusKm = _selectedDistance / 2;
    final tripPoints = <LatLng>[];
    const numPoints = 8;

    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * pi;
      final latOffset = (radiusKm / 111.32) * 0.7 * (0.5 + 0.5 * (i % 2 == 0 ? 1 : -1));
      final lngOffset = (radiusKm / (111.32 * cos(center.latitude * pi / 180))) * 0.7 * (0.5 + 0.5 * (i % 3 == 0 ? 1 : -1));
      tripPoints.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
    }

    tripPoints.add(tripPoints.first);
    _polylineCoordinates.clear();
    _polylineCoordinates.addAll(tripPoints);
    _updatePolyline();

    final tripPolyline = Polyline(
      polylineId: const PolylineId('trip_loop'),
      color: Colors.blue,
      width: 4,
      points: tripPoints,
      geodesic: true,
    );

    final poiNames = ['Zřícenina', 'Vyhlídka', 'Park', 'Jezero'];
    final tripMarkers = <Marker>[];

    for (int i = 0; i < poiNames.length && i < tripPoints.length - 1; i++) {
      final pointIndex = ((i + 1) * tripPoints.length ~/ 5).clamp(0, tripPoints.length - 2);
      final point = tripPoints[pointIndex];
      tripMarkers.add(Marker(
        markerId: MarkerId('trip_poi_$i'),
        position: point,
        infoWindow: InfoWindow(title: poiNames[i]),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      ));
      _tripPoints.add({'name': poiNames[i], 'position': point});
    }

    setState(() {
      _polylines.add(tripPolyline);
      _markers.addAll(tripMarkers);
      _showTripOptions = false;
    });
  }

  void _generateDestinationRoute(LatLng destination) {
    if (_lastPosition == null) return;
    final start = LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
    final midpoint = LatLng(
      (start.latitude + destination.latitude) / 2,
      (start.longitude + destination.longitude) / 2 + 0.001,
    );
    final routePoints = [start, midpoint, destination];
    _polylineCoordinates.clear();
    _polylineCoordinates.addAll(routePoints);
    _updatePolyline();

    _markers.removeWhere((m) => m.markerId.value == 'trip_dest');
    _markers.add(Marker(
      markerId: const MarkerId('trip_dest'),
      position: destination,
      infoWindow: const InfoWindow(title: 'Cíl cesty'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    ));

    _tripPoints.clear();
    _tripPoints.add({'name': 'Cíl cesty', 'position': destination});
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
    _positionStream.listen((position) {
      if (!mounted) return;
      final newPoint = LatLng(position.latitude, position.longitude);
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
        _mapController.animateCamera(
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
                  _tripPoints.clear();
                  _generateDestinationRoute(latLng);
                });
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cíl nastaven. Trasa vytvořena.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _simulateGPSMovement() {
    if (_lastPosition == null) return;
    final random = Random();
    for (int i = 0; i < 5; i++) {
      final latOffset = (random.nextDouble() - 0.5) * 0.001;
      final lngOffset = (random.nextDouble() - 0.5) * 0.001;
      final newPoint = LatLng(
        _lastPosition!.latitude + latOffset,
        _lastPosition!.longitude + lngOffset,
      );
      _breadcrumbsCoordinates.add(newPoint);
    }
    _updateBreadcrumbsPolyline();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS simulace spuštěna - přidáno 5 bodů')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

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
                      _tripPoints.clear();
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
          Positioned(
            top: topPadding + 72,
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
                          const Text(
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
          Positioned(
            bottom: 200,
            right: 20,
            child: FloatingActionButton(
              onPressed: _simulateGPSMovement,
              backgroundColor: const Color(0xFFBFFF00),
              child: const Icon(Icons.play_arrow, color: Colors.black),
              tooltip: 'Simulate GPS Movement',
            ),
          ),
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
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
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTripOptions = !_showTripOptions;
                        });
                      },
                      icon: const Icon(Icons.explore),
                      label: Text(
                        _tripMode == 'loop' ? 'Okruh v okolí' : 'Cesta do cíle',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all(const Color(0xFFBFFF00)),
                        foregroundColor: MaterialStateProperty.all(Colors.black),
                        elevation: MaterialStateProperty.all(0),
                        shape: MaterialStateProperty.all(
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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFBFFF00),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'loop') {
                          setState(() {
                            _tripMode = 'loop';
                            _showTripOptions = true;
                            _isSelectingDestination = false;
                            _showDestinationSearch = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Okruh vybrán. Vyberte délku a generujte.')),
                          );
                        } else if (value == 'destination') {
                          setState(() {
                            _tripMode = 'destination';
                            _showTripOptions = false;
                            _isSelectingDestination = true;
                            _showDestinationSearch = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Klikněte do mapy pro cíl')),
                          );
                        } else if (value == 'search') {
                          setState(() {
                            _tripMode = 'destination';
                            _showTripOptions = false;
                            _isSelectingDestination = false;
                            _showDestinationSearch = true;
                          });
                        }
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
                        const PopupMenuItem(
                          value: 'search',
                          child: Text('Hledat destinaci'),
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
          if (_showDestinationSearch)
            Positioned(
              bottom: 190,
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
                      TextField(
                        controller: _destinationController,
                        decoration: const InputDecoration(
                          labelText: 'Hledat destinaci',
                          hintText: 'Zadejte cíl cesty',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          setState(() {
                            _showDestinationSearch = false;
                            _isSelectingDestination = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Klikněte do mapy pro cíl')),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showDestinationSearch = false;
                              });
                            },
                            child: const Text('Zrušit'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showDestinationSearch = false;
                                _isSelectingDestination = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Klikněte do mapy pro cíl')),
                              );
                            },
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(const Color(0xFFBFFF00)),
                              foregroundColor: MaterialStateProperty.all(Colors.black),
                            ),
                            child: const Text('Hledat'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showTripOptions)
            Positioned(
              bottom: 270,
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
                              _generateTripLoop();
                            },
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(const Color(0xFFBFFF00)),
                              foregroundColor: MaterialStateProperty.all(Colors.black),
                            ),
                            child: const Text('Generovat'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_tripPoints.isNotEmpty)
            Positioned(
              bottom: 280,
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
}
