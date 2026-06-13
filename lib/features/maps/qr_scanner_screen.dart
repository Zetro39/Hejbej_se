import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SKENOVAT QR KÓD',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E272C),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                setState(() {
                  _scanned = true;
                });
                _controller.stop();
                Navigator.of(context).pop(barcodes.first.rawValue);
              }
            },
          ),
          
          // Sci-Fi custom painter overlay with animated laser line
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SciFiScannerOverlayPainter(
                    animationValue: _animController.value,
                  ),
                );
              },
            ),
          ),
          
          // Glassmorphic instructions overlay
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E272C).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFBFFF00).withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zamiřte na QR kód',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Držte kód v označeném rámečku pro rychlé naskenování.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
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

class SciFiScannerOverlayPainter extends CustomPainter {
  final double animationValue;

  SciFiScannerOverlayPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    
    // Scanner viewport rectangle
    const double boxSize = 250.0;
    final double left = (width - boxSize) / 2;
    final double top = (height - boxSize) / 2;
    final Rect rect = Rect.fromLTWH(left, top, boxSize, boxSize);
    
    // 1. Draw viewport mask (transparent inner, darkened outer)
    final maskPaint = Paint()..color = const Color(0xFF263238).withOpacity(0.65);
    
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, width, top), maskPaint);
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, rect.bottom, width, height - rect.bottom), maskPaint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, top, left, boxSize), maskPaint);
    // Right
    canvas.drawRect(Rect.fromLTWH(rect.right, top, width - rect.right, boxSize), maskPaint);

    // 2. Draw border frame corners
    final cornerPaint = Paint()
      ..color = const Color(0xFFBFFF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const double cornerLength = 32.0;

    // Top Left Corner
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left, rect.top + cornerLength), cornerPaint);

    // Top Right Corner
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right - cornerLength, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), cornerPaint);

    // Bottom Left Corner
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left, rect.bottom - cornerLength), cornerPaint);

    // Bottom Right Corner
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right - cornerLength, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);

    // 3. Draw scanning laser line
    final double laserY = rect.top + rect.height * animationValue;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFBFFF00).withOpacity(0.01),
          const Color(0xFFBFFF00),
          const Color(0xFFBFFF00).withOpacity(0.01),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(rect.left, laserY - 2.5, rect.right, laserY + 2.5));

    canvas.drawRect(Rect.fromLTRB(rect.left + 6, laserY - 2.5, rect.right - 6, laserY + 2.5), laserPaint);

    // Light neon glow behind laser
    final laserGlowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFBFFF00).withOpacity(0.12),
          const Color(0xFFBFFF00).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTRB(rect.left, laserY - 24, rect.right, laserY));
    canvas.drawRect(Rect.fromLTRB(rect.left + 6, laserY - 24, rect.right - 6, laserY), laserGlowPaint);
  }

  @override
  bool shouldRepaint(covariant SciFiScannerOverlayPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
