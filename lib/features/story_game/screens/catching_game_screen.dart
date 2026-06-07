import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CatchingGameScreen extends StatefulWidget {
  final VoidCallback onSolved;

  const CatchingGameScreen({super.key, required this.onSolved});

  @override
  State<CatchingGameScreen> createState() => _CatchingGameScreenState();
}

class _CatchingGameScreenState extends State<CatchingGameScreen> with SingleTickerProviderStateMixin {
  final List<_Spark> _sparks = [];
  final List<_ExplosionParticle> _particles = [];
  final math.Random _random = math.Random();
  int _score = 0;
  final int _targetScore = 15;
  int _timeLeft = 30; // 30 seconds limit
  Timer? _gameTimer;
  Timer? _spawnTimer;
  bool _isGameOver = false;
  bool _isSuccess = false;
  late AnimationController _sparkLoopController;
  final FlutterTts _tts = FlutterTts();
  double _shakeOffset = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Position/animation update loop
    _sparkLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateSparks);
    _sparkLoopController.repeat();

    // Start game loop timers
    _startGameTimers();
    _initTts().then((_) {
      _speak('Musím pochytat světlušky a nabít amulet dřív, než vyprší čas!');
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("cs-CZ");
      await _tts.setPitch(0.85);
      await _tts.setSpeechRate(0.45);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _triggerShake() {
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || count > 8) {
        timer.cancel();
        setState(() {
          _shakeOffset = 0.0;
        });
        return;
      }
      setState(() {
        _shakeOffset = (count % 2 == 0) ? 6.0 : -6.0;
      });
      count++;
    });
  }

  void _startGameTimers() {
    // Spawn a spark every 800ms
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted || _isGameOver) return;
      _spawnSpark();
    });

    // Count down time every second
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _endGame(false);
        }
      });
    });

    // Spawn initial sparks
    for (int i = 0; i < 4; i++) {
      _spawnSpark();
    }
  }

  void _spawnSpark() {
    // Determine spark type: 75% normal, 15% unstable (red), 10% golden
    final double typeRoll = _random.nextDouble();
    String type = 'normal';
    Color sparkColor = [
      Colors.amberAccent,
      Colors.orangeAccent,
      Colors.cyanAccent,
      Colors.limeAccent,
    ][_random.nextInt(4)];
    double size = 30.0 + _random.nextDouble() * 15.0;

    if (typeRoll > 0.90) {
      type = 'golden';
      sparkColor = Colors.amber;
      size = 26.0; // smaller
    } else if (typeRoll > 0.75) {
      type = 'unstable';
      sparkColor = Colors.red;
      size = 36.0; // larger
    }

    // Velocity multiplier based on type
    double speedMult = 1.0;
    if (type == 'golden') speedMult = 2.0;
    if (type == 'unstable') speedMult = 0.8;

    setState(() {
      _sparks.add(_Spark(
        id: DateTime.now().microsecondsSinceEpoch.toString() + _random.nextInt(100).toString(),
        x: 0.1 + _random.nextDouble() * 0.8,
        y: 0.1 + _random.nextDouble() * 0.7,
        vx: (-0.015 + _random.nextDouble() * 0.03) * speedMult,
        vy: (-0.015 + _random.nextDouble() * 0.03) * speedMult,
        color: sparkColor,
        size: size,
        type: type,
      ));
    });
  }

  void _updateSparks() {
    if (_isGameOver) return;
    
    setState(() {
      // 1. Move sparks and apply sine wave floating effect
      for (var spark in _sparks) {
        spark.x += spark.vx;
        spark.y += spark.vy;

        // Bounce walls
        if (spark.x <= 0.05 || spark.x >= 0.95) spark.vx *= -1;
        if (spark.y <= 0.05 || spark.y >= 0.95) spark.vy *= -1;

        // Floating wiggle effect
        spark.y += math.sin(DateTime.now().millisecondsSinceEpoch * 0.005 + spark.x * 100) * 0.001;
      }

      // 2. Update particle explosion physics
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.x += p.vx;
        p.y += p.vy;
        p.opacity -= 0.04;
        if (p.opacity <= 0) {
          _particles.removeAt(i);
        }
      }
    });
  }

  void _spawnExplosion(double x, double y, Color color) {
    for (int i = 0; i < 12; i++) {
      final double angle = _random.nextDouble() * 2 * math.pi;
      final double speed = 0.003 + _random.nextDouble() * 0.008;
      _particles.add(_ExplosionParticle(
        x: x,
        y: y,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        size: 2.0 + _random.nextDouble() * 3.5,
        color: color,
      ));
    }
  }

  void _onSparkTap(_Spark spark) {
    if (_isGameOver) return;

    _spawnExplosion(spark.x, spark.y, spark.color);

    setState(() {
      _sparks.removeWhere((s) => s.id == spark.id);
      
      if (spark.type == 'golden') {
        _score = math.min(_targetScore, _score + 3);
      } else if (spark.type == 'unstable') {
        _timeLeft = math.max(0, _timeLeft - 3);
        _speak('Pozor, nestabilní jiskra!');
        _triggerShake();
      } else {
        _score = math.min(_targetScore, _score + 1);
      }
    });

    if (_score >= _targetScore) {
      _endGame(true);
    }
  }

  void _endGame(bool success) {
    _spawnTimer?.cancel();
    _gameTimer?.cancel();
    _sparkLoopController.stop();

    setState(() {
      _isGameOver = true;
      _isSuccess = success;
    });

    if (success) {
      _speak('Amulet plně září! Dokázal jsem to a světlušky jsou spoutané.');
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) {
          widget.onSolved();
          Navigator.pop(context);
        }
      });
    } else {
      _speak('Sakra! Světlušky mi ulétly. Musím to zkusit znova.');
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _sparkLoopController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HUD Top bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: const Border(
                  bottom: BorderSide(color: Colors.black38, width: 2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🔋 NABÍJENÍ AMULETU',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Nabití: $_score / $_targetScore',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.cyan, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '⏳ ZBÝVAJÍCÍ ČAS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_timeLeft s',
                        style: TextStyle(
                          color: _timeLeft <= 6 ? Colors.redAccent : Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            if (_timeLeft <= 6)
                              const Shadow(color: Colors.red, blurRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Linear Progress Indicator with Neon Glow
            LinearProgressIndicator(
              value: _score / _targetScore,
              backgroundColor: const Color(0xFF262626),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              minHeight: 8,
            ),

            // Game Board Viewport
            Expanded(
              child: Transform.translate(
                offset: Offset(_shakeOffset, 0),
                child: _isGameOver
                    ? Center(
                        child: Container(
                          width: 300,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            gradient: const RadialGradient(
                              colors: [Color(0xFF262626), Color(0xFF0F0F0F)],
                              radius: 1.2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _isSuccess ? Colors.cyanAccent : Colors.redAccent,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isSuccess ? Icons.offline_bolt : Icons.timer_off_outlined,
                                color: _isSuccess ? Colors.cyanAccent : Colors.redAccent,
                                size: 80,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSuccess ? 'AMULET JE NABITÝ!' : 'ČAS VYPRŠEL!',
                                style: TextStyle(
                                  color: _isSuccess ? Colors.cyanAccent : Colors.redAccent,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isSuccess
                                    ? 'Energie živlů byla úspěšně spoutána a brána oltáře se probouzí k životu.'
                                    : 'Nepodařilo se zachytit dostatek jisker a světlušky se rozletěly do bažin.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                              ),
                              if (!_isSuccess) ...[
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _score = 0;
                                      _timeLeft = 30;
                                      _isGameOver = false;
                                      _isSuccess = false;
                                      _sparks.clear();
                                      _particles.clear();
                                    });
                                    _startGameTimers();
                                    _sparkLoopController.repeat();
                                    _speak('Pokus číslo dva. Světlušky, ukažte se!');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    elevation: 6,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Zkusit znovu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final height = constraints.maxHeight;

                          return Stack(
                            children: [
                              // 1. Dark starry sky background
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xFF0F172A), Color(0xFF020617)],
                                    ),
                                  ),
                                ),
                              ),

                              // 2. Parallax: Giant glowing Moon
                              Positioned(
                                top: 40,
                                right: 50,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.yellow.shade100,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.yellow.shade200.withOpacity(0.4),
                                        blurRadius: 30,
                                        spreadRadius: 6,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 3. Parallax: Distant Swamp Hills/Trees
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _SwampBackgroundPainter(),
                                ),
                              ),

                              // 4. Instructions Overlay
                              const Positioned(
                                top: 20,
                                left: 24,
                                right: 24,
                                child: Text(
                                  'Chytej barevné jiskry! 🌟 Zlaté dávají +3 body, červené ⚠️ ti odečtou 3 sekundy!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                              // 5. Tapped particles explosion layer
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ParticlePainter(particles: _particles),
                                ),
                              ),

                              // 6. Flying sparks/fireflies layer
                              ..._sparks.map((spark) {
                                final posX = spark.x * width;
                                final posY = spark.y * height;

                                // Custom widget styles based on type
                                Widget sparkWidget;
                                if (spark.type == 'golden') {
                                  sparkWidget = Container(
                                    width: spark.size,
                                    height: spark.size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amberAccent.withOpacity(0.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.amber,
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.star, color: Colors.white, size: 14),
                                    ),
                                  );
                                } else if (spark.type == 'unstable') {
                                  sparkWidget = Container(
                                    width: spark.size,
                                    height: spark.size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.redAccent.withOpacity(0.5),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.red,
                                          blurRadius: 22,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                      border: Border.all(color: Colors.redAccent.shade100, width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                                    ),
                                  );
                                } else {
                                  // normal spark
                                  sparkWidget = Container(
                                    width: spark.size,
                                    height: spark.size,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: spark.color.withOpacity(0.4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: spark.color,
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: spark.size * 0.3,
                                        height: spark.size * 0.3,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Positioned(
                                  left: posX - (spark.size / 2),
                                  top: posY - (spark.size / 2),
                                  child: GestureDetector(
                                    onTap: () => _onSparkTap(spark),
                                    child: sparkWidget,
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spark {
  final String id;
  double x;
  double y;
  double vx;
  double vy;
  final Color color;
  final double size;
  final String type; // 'normal', 'golden', 'unstable'

  _Spark({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.type,
  });
}

class _ExplosionParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double opacity = 1.0;

  _ExplosionParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_ExplosionParticle> particles;
  _ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _SwampBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Draw distant swamp hills
    final hillPaint = Paint()
      ..color = const Color(0xFF0F172A).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final path1 = Path();
    path1.moveTo(0, h);
    path1.quadraticBezierTo(w * 0.25, h - 50, w * 0.5, h - 25);
    path1.quadraticBezierTo(w * 0.75, h, w, h - 35);
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    canvas.drawPath(path1, hillPaint);

    final path2 = Path();
    hillPaint.color = const Color(0xFF020617);
    path2.moveTo(0, h);
    path2.quadraticBezierTo(w * 0.3, h - 25, w * 0.6, h - 40);
    path2.quadraticBezierTo(w * 0.8, h - 20, w, h - 15);
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    canvas.drawPath(path2, hillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
