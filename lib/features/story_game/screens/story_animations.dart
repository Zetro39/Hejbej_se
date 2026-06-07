import 'dart:math';
import 'package:flutter/material.dart';

class ImmersiveWeatherParticles extends StatefulWidget {
  final String particleType; // 'leaves', 'fireflies', 'fog', 'magic'
  const ImmersiveWeatherParticles({super.key, required this.particleType});

  @override
  State<ImmersiveWeatherParticles> createState() => _ImmersiveWeatherParticlesState();
}

class _ImmersiveWeatherParticlesState extends State<ImmersiveWeatherParticles> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    
    // Initialize particles after frame layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        int count = widget.particleType == 'fog' ? 6 : 25;
        for (int i = 0; i < count; i++) {
          _particles.add(_createParticle(size));
        }
      }
    });
  }

  _Particle _createParticle(Size size) {
    double x = _random.nextDouble() * size.width;
    double y = _random.nextDouble() * size.height;
    double vx = (widget.particleType == 'leaves') ? (0.2 + _random.nextDouble() * 0.8) : (-0.4 + _random.nextDouble() * 0.8);
    double vy = (widget.particleType == 'leaves') ? (0.8 + _random.nextDouble() * 1.2) : (-0.3 + _random.nextDouble() * 0.6);
    double radius = (widget.particleType == 'fog') ? (70 + _random.nextDouble() * 90) : (1.5 + _random.nextDouble() * 3.5);
    double opacity = (widget.particleType == 'fog') ? (0.04 + _random.nextDouble() * 0.08) : (0.2 + _random.nextDouble() * 0.8);
    return _Particle(
      x: x, y: y, vx: vx, vy: vy,
      radius: radius, opacity: opacity,
      angle: _random.nextDouble() * pi * 2,
      angularVelocity: -0.03 + _random.nextDouble() * 0.06,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_particles.isEmpty) return const SizedBox.shrink();
        final size = MediaQuery.of(context).size;
        
        // Update physics
        for (var p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          p.angle += p.angularVelocity;
          
          if (widget.particleType == 'leaves') {
            if (p.y > size.height) {
              p.y = -20;
              p.x = _random.nextDouble() * size.width;
            }
            if (p.x > size.width) p.x = -10;
          } else {
            if (p.x < -120) p.x = size.width + 50;
            if (p.x > size.width + 120) p.x = -50;
            if (p.y < -120) p.y = size.height + 50;
            if (p.y > size.height + 120) p.y = -50;
          }
        }
        
        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ParticlePainter(particles: _particles, type: widget.particleType),
          ),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;
  double opacity;
  double angle;
  double angularVelocity;

  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.radius, required this.opacity,
    required this.angle, required this.angularVelocity,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final String type;
  _ParticlePainter({required this.particles, required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (var p in particles) {
      if (type == 'leaves') {
        paint.color = Colors.orangeAccent.withOpacity(p.opacity);
        canvas.save();
        canvas.translate(p.x, p.y);
        canvas.rotate(p.angle);
        // Simple leaf shape
        final path = Path()
          ..moveTo(0, -p.radius * 2)
          ..quadraticBezierTo(p.radius, -p.radius, 0, p.radius * 2)
          ..quadraticBezierTo(-p.radius, -p.radius, 0, -p.radius * 2);
        canvas.drawPath(path, paint);
        canvas.restore();
      } else if (type == 'fireflies') {
        final glow = RadialGradient(
          colors: [
            Colors.yellowAccent.withOpacity(p.opacity),
            Colors.yellowAccent.withOpacity(0.0),
          ],
        );
        paint.shader = glow.createShader(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.radius * 4.5));
        canvas.drawCircle(Offset(p.x, p.y), p.radius * 4.5, paint);
        paint.shader = null;
        paint.color = Colors.white.withOpacity(p.opacity);
        canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
      } else if (type == 'fog') {
        final glow = RadialGradient(
          colors: [
            Colors.white.withOpacity(p.opacity),
            Colors.white.withOpacity(0.0),
          ],
        );
        paint.shader = glow.createShader(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.radius));
        canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
        paint.shader = null;
      } else if (type == 'magic') {
        paint.color = Colors.cyanAccent.withOpacity(p.opacity);
        canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedBobbingWidget extends StatefulWidget {
  final Widget child;
  const AnimatedBobbingWidget({super.key, required this.child});

  @override
  State<AnimatedBobbingWidget> createState() => _AnimatedBobbingWidgetState();
}

class _AnimatedBobbingWidgetState extends State<AnimatedBobbingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -_animation.value),
          child: widget.child,
        );
      },
    );
  }
}
