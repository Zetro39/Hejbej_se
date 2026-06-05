import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';

class ArNavigationScreen extends StatefulWidget {
  final List<LatLng> routePoints;

  const ArNavigationScreen({super.key, required this.routePoints});

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  StreamSubscription<Position>? _locationSubscription;
  Position? _currentPosition;
  Position? _previousPosition;
  double _currentHeading = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('Žádné kamery nebyly nalezeny.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Chyba při inicializaci kamery: $e');
    }
  }

  void _startLocationTracking() {
    _locationSubscription = LocationService().positionUpdateStream.listen((position) {
      if (!mounted) return;

      double heading = position.heading;
      // Fallback heading calculation if geolocator heading is not available/zero
      if (heading == 0.0 && _previousPosition != null) {
        heading = Geolocator.bearingBetween(
          _previousPosition!.latitude,
          _previousPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }

      setState(() {
        _currentPosition = position;
        if (heading != 0.0) {
          _currentHeading = heading;
        }
        _previousPosition = position;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _cameraController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.lime),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Live Camera Preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // AR Custom Paint Overlay
          if (_currentPosition != null && widget.routePoints.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: ArPathPainter(
                  userPos: _currentPosition!,
                  userHeading: _currentHeading,
                  routePoints: widget.routePoints,
                ),
              ),
            )
          else
            const Positioned.fill(
              child: Center(
                child: Card(
                  color: Colors.black54,
                  margin: EdgeInsets.all(32),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Čekám na GPS signál...',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),

          // Top App Bar / Back button overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Overlay Guide Banner
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.lime.withOpacity(0.5), width: 1.5),
              ),
              child: Row(
                children: const [
                  Icon(Icons.remove_red_eye, color: Colors.lime, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'AR Režim: Sledujte zelenou trasu na displeji přímo před sebou.',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 3D Perspective Painter for GPS Route Points
class ArPathPainter extends CustomPainter {
  final Position userPos;
  final double userHeading;
  final List<LatLng> routePoints;

  ArPathPainter({
    required this.userPos,
    required this.userHeading,
    required this.routePoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final horizonY = height / 2; // Horizon line at vertical center
    const double cameraFovX = 60.0; // Horizontal Field of View in degrees

    final List<Offset> projectedPoints = [];
    final List<double> projectedThickness = [];

    for (final point in routePoints) {
      // 1. Calculate bearing and distance to route point
      final bearing = Geolocator.bearingBetween(
        userPos.latitude,
        userPos.longitude,
        point.latitude,
        point.longitude,
      );

      final distance = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        point.latitude,
        point.longitude,
      );

      // 2. Compute relative bearing to user heading
      double relativeBearing = bearing - userHeading;
      if (relativeBearing > 180) relativeBearing -= 360;
      if (relativeBearing < -180) relativeBearing += 360;

      // Skip points that are behind the user (greater than 90 degrees left/right)
      if (relativeBearing.abs() > 90) continue;

      // 3. Project X based on horizontal FOV
      final x = centerX + (relativeBearing / (cameraFovX / 2)) * centerX;

      // 4. Project Y based on 3D perspective mapping
      // Closer points are drawn at the bottom (y = height).
      // Further points compress towards the horizon line (y = horizonY).
      // Math: y = horizonY + (1 / (1 + distance * k)) * (height - horizonY)
      const double depthFactor = 0.08;
      final perspectiveDepth = 1.0 / (1.0 + distance * depthFactor);
      final y = horizonY + (1.0 - (1.0 - perspectiveDepth)) * (height - horizonY);

      // 5. Line thickness based on depth (closer points are wider)
      const double baseThickness = 60.0;
      final thickness = baseThickness * perspectiveDepth;

      // Only draw points within reasonable distance (e.g. 150m) and within canvas bounds
      if (distance < 150.0 && y > horizonY) {
        projectedPoints.add(Offset(x, y));
        projectedThickness.add(thickness);
      }
    }

    if (projectedPoints.length < 2) return;

    // Draw segment by segment with changing thickness for true perspective
    for (int i = 0; i < projectedPoints.length - 1; i++) {
      final p1 = projectedPoints[i];
      final p2 = projectedPoints[i + 1];
      final thickness = (projectedThickness[i] + projectedThickness[i + 1]) / 2;

      // Neon green paint with glowing effect
      final paint = Paint()
        ..color = const Color(0xFFBFFF00).withOpacity(0.75) // Glowing lime
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Draw glowing shadow
      final shadowPaint = Paint()
        ..color = const Color(0xFFBFFF00).withOpacity(0.2)
        ..strokeWidth = thickness * 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1, p2, shadowPaint);
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ArPathPainter oldDelegate) {
    return oldDelegate.userPos != userPos ||
        oldDelegate.userHeading != userHeading ||
        oldDelegate.routePoints != routePoints;
  }
}
