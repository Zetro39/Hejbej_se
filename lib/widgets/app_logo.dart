import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppLogo extends StatefulWidget {
  final double size;
  final bool animated;

  const AppLogo({
    super.key,
    this.size = 100.0,
    this.animated = true,
  });

  @override
  State<AppLogo> createState() => _AppLogoState();
}

class _AppLogoState extends State<AppLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AppLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: AppLogoPainter(
            animationValue: _controller.value,
            animated: widget.animated,
          ),
        );
      },
    );
  }
}

class AppLogoPainter extends CustomPainter {
  final double animationValue;
  final bool animated;

  AppLogoPainter({
    required this.animationValue,
    required this.animated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final center = Offset(radius, radius);

    // 1. Draw ambient glow
    final glowPaint = Paint()
      ..color = const Color(0xFFBFFF00).withOpacity(0.12 + (animated ? 0.05 * math.sin(animationValue * math.pi * 2) : 0.0))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.4);
    canvas.drawCircle(center, radius * 0.8, glowPaint);

    // 2. Draw outer rotating running track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08
      ..strokeCap = StrokeCap.round;

    final trackRect = Rect.fromCircle(center: center, radius: radius * 0.85);
    final double rotationAngle = animated ? (animationValue * math.pi * 2) : 0.0;

    // We draw three arcs to make it look like a running track with lanes
    final trackGradient = SweepGradient(
      colors: const [
        Color(0xFFBFFF00), // Neon Lime
        Color(0xFF1B5E20), // Forest Green
        Color(0xFFBFFF00),
      ],
      transform: GradientRotation(rotationAngle),
    );
    trackPaint.shader = trackGradient.createShader(trackRect);
    canvas.drawArc(trackRect, 0, math.pi * 1.5, false, trackPaint);

    // Inner details (lane dashes)
    final dashPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.02
      ..color = const Color(0xFF263238).withOpacity(0.5);
    canvas.drawCircle(center, radius * 0.76, dashPaint);

    // 3. Draw inner lime slice (representing currency "Limetky")
    // Pulse animation for inner circle
    final double pulse = animated ? (1.0 + 0.04 * math.sin(animationValue * math.pi * 4)) : 1.0;
    final double limeRadius = radius * 0.65 * pulse;

    final limePaint = Paint()
      ..color = const Color(0xFFBFFF00).withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, limeRadius, limePaint);

    // Lime rim
    final rimPaint = Paint()
      ..color = const Color(0xFFBFFF00)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.04;
    canvas.drawCircle(center, limeRadius, rimPaint);

    // Lime segments (8 Spokes)
    final spokePaint = Paint()
      ..color = const Color(0xFFBFFF00).withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.03;

    for (int i = 0; i < 8; i++) {
      final double angle = (i * math.pi / 4) + (animated ? (animationValue * 0.2) : 0.0);
      final spokeEnd = Offset(
        center.dx + (limeRadius - radius * 0.06) * math.cos(angle),
        center.dy + (limeRadius - radius * 0.06) * math.sin(angle),
      );
      canvas.drawLine(center, spokeEnd, spokePaint);
    }

    // 4. Draw stylized runner silhouette leaping forward
    final runnerPaint = Paint()
      ..color = const Color(0xFF263238)
      ..style = PaintingStyle.fill;

    // Center shifting for bobbing runner
    final double bobbing = animated ? (radius * 0.03 * math.cos(animationValue * math.pi * 4)) : 0.0;
    final runnerCenter = Offset(center.dx, center.dy + bobbing);

    canvas.save();
    canvas.translate(runnerCenter.dx, runnerCenter.dy);
    // Draw running figure
    // Head
    canvas.drawCircle(Offset(radius * 0.08, -radius * 0.28), radius * 0.07, runnerPaint);

    // Torso (leaping forward shape)
    final torsoPath = Path()
      ..moveTo(-radius * 0.08, -radius * 0.18)
      ..lineTo(radius * 0.14, -radius * 0.16)
      ..lineTo(radius * 0.05, radius * 0.06)
      ..lineTo(-radius * 0.08, -radius * 0.02)
      ..close();
    canvas.drawPath(torsoPath, runnerPaint);

    // Back leg (bent backward)
    final backLegPath = Path()
      ..moveTo(-radius * 0.06, radius * 0.02)
      ..lineTo(-radius * 0.22, radius * 0.08)
      ..lineTo(-radius * 0.26, radius * 0.24)
      ..lineTo(-radius * 0.20, radius * 0.24)
      ..lineTo(-radius * 0.16, radius * 0.12)
      ..close();
    canvas.drawPath(backLegPath, runnerPaint);

    // Front leg (bent forward/upward in step)
    final frontLegPath = Path()
      ..moveTo(radius * 0.04, radius * 0.04)
      ..lineTo(radius * 0.18, radius * 0.14)
      ..lineTo(radius * 0.12, radius * 0.32)
      ..lineTo(radius * 0.06, radius * 0.30)
      ..lineTo(radius * 0.12, radius * 0.16)
      ..close();
    canvas.drawPath(frontLegPath, runnerPaint);

    // Back arm (swinging back)
    final backArmPath = Path()
      ..moveTo(-radius * 0.06, -radius * 0.16)
      ..lineTo(-radius * 0.22, -radius * 0.12)
      ..lineTo(-radius * 0.28, -radius * 0.02)
      ..lineTo(-radius * 0.24, 0.0)
      ..lineTo(-radius * 0.18, -radius * 0.08)
      ..close();
    canvas.drawPath(backArmPath, runnerPaint);

    // Front arm (pumping forward)
    final frontArmPath = Path()
      ..moveTo(radius * 0.10, -radius * 0.17)
      ..lineTo(radius * 0.26, -radius * 0.18)
      ..lineTo(radius * 0.32, -radius * 0.08)
      ..lineTo(radius * 0.28, -radius * 0.06)
      ..lineTo(radius * 0.22, -radius * 0.14)
      ..close();
    canvas.drawPath(frontArmPath, runnerPaint);

    canvas.restore();

    // 5. Draw glowing stars/sparkles around the runner
    if (animated) {
      final starPaint = Paint()
        ..color = const Color(0xFFBFFF00)
        ..style = PaintingStyle.fill;
      
      final starPos1 = Offset(
        center.dx + radius * 0.45 * math.cos(animationValue * math.pi * 2 + 1.0),
        center.dy + radius * 0.45 * math.sin(animationValue * math.pi * 2 + 1.0),
      );
      canvas.drawCircle(starPos1, radius * 0.04, starPaint);

      final starPos2 = Offset(
        center.dx + radius * 0.55 * math.cos(animationValue * math.pi * 2 + 4.2),
        center.dy + radius * 0.55 * math.sin(animationValue * math.pi * 2 + 4.2),
      );
      canvas.drawCircle(starPos2, radius * 0.03, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AppLogoPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.animated != animated;
  }
}
