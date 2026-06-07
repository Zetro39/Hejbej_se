import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class CatchingGameScreen extends StatefulWidget {
  final VoidCallback onSolved;

  const CatchingGameScreen({super.key, required this.onSolved});

  @override
  State<CatchingGameScreen> createState() => _CatchingGameScreenState();
}

class _CatchingGameScreenState extends State<CatchingGameScreen> with SingleTickerProviderStateMixin {
  final List<_Spark> _sparks = [];
  final Random _random = Random();
  int _score = 0;
  final int _targetScore = 15;
  int _timeLeft = 30; // 30 seconds limit
  Timer? _gameTimer;
  Timer? _spawnTimer;
  bool _isGameOver = false;
  bool _isSuccess = false;
  late AnimationController _sparkLoopController;

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
    setState(() {
      _sparks.add(_Spark(
        id: DateTime.now().microsecondsSinceEpoch.toString() + _random.nextInt(100).toString(),
        x: 0.1 + _random.nextDouble() * 0.8,
        y: 0.1 + _random.nextDouble() * 0.7,
        vx: (-0.02 + _random.nextDouble() * 0.04),
        vy: (-0.02 + _random.nextDouble() * 0.04),
        color: [
          Colors.amberAccent,
          Colors.orangeAccent,
          Colors.cyanAccent,
          Colors.limeAccent,
        ][_random.nextInt(4)],
        size: 25.0 + _random.nextDouble() * 20.0,
      ));
    });
  }

  void _updateSparks() {
    if (_isGameOver) return;
    
    setState(() {
      for (var spark in _sparks) {
        // Move
        spark.x += spark.vx;
        spark.y += spark.vy;

        // Bounce walls
        if (spark.x <= 0.05 || spark.x >= 0.95) spark.vx *= -1;
        if (spark.y <= 0.05 || spark.y >= 0.95) spark.vy *= -1;
      }
    });
  }

  void _onSparkTap(String id) {
    if (_isGameOver) return;

    setState(() {
      _sparks.removeWhere((s) => s.id == id);
      _score++;
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
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onSolved();
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _spawnTimer?.cancel();
    _sparkLoopController.dispose();
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
              color: Colors.grey.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('🔋 Nabíjení amuletu', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        'Nabití: $_score / $_targetScore',
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('⏳ Zbývající čas', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '$_timeLeft s',
                        style: TextStyle(
                          color: _timeLeft <= 5 ? Colors.redAccent : Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Linear Progress Indicator
            LinearProgressIndicator(
              value: _score / _targetScore,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              minHeight: 8,
            ),

            // Game Board Viewport
            Expanded(
              child: _isGameOver
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _isSuccess ? Colors.green : Colors.red, width: 2),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSuccess ? Icons.offline_bolt : Icons.error_outline,
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
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _isSuccess
                                  ? 'Energie živlů byla úspěšně spoutána.'
                                  : 'Nepodařilo se zachytit dostatek jisker. Zkus to znovu.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
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
                                  });
                                  _startGameTimers();
                                  _sparkLoopController.repeat();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Zkusit znovu', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            // Dark background grid texture
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      const Color(0xFF0F0F0F),
                                      Colors.black,
                                    ],
                                    radius: 1.2,
                                  ),
                                ),
                              ),
                            ),

                            // Background instructions
                            const Positioned(
                              top: 24,
                              left: 24,
                              right: 24,
                              child: Text(
                                'Rychle klikej (tuckej) na poletující magické jiskry, než zmizí nebo vyprší čas!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white24, fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ),

                            // Render flying sparks
                            ..._sparks.map((spark) {
                              final posX = spark.x * width;
                              final posY = spark.y * height;

                              return Positioned(
                                left: posX - (spark.size / 2),
                                top: posY - (spark.size / 2),
                                child: GestureDetector(
                                  onTap: () => _onSparkTap(spark.id),
                                  child: Container(
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
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
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

  _Spark({
    required this.id,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
  });
}
