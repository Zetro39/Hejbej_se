import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/wheel_of_fortune_model.dart';
import '../../services/auth_service.dart';
import 'widgets/task_doodle_widget.dart';

class WheelOfFortuneScreen extends StatefulWidget {
  final List<String> playerNames;
  final WheelOfFortune wheel;
  final Map<String, List<String>> playerHistory; // player -> taskIds already completed
  final Function(Map<String, WheelTask> assignments) onComplete;

  const WheelOfFortuneScreen({
    super.key,
    required this.playerNames,
    required this.wheel,
    required this.playerHistory,
    required this.onComplete,
  });

  @override
  State<WheelOfFortuneScreen> createState() => _WheelOfFortuneScreenState();
}

class _WheelOfFortuneScreenState extends State<WheelOfFortuneScreen> with TickerProviderStateMixin {
  late List<String> _players;
  int _currentPlayerIndex = 0;

  // Spin status
  bool _isSpinning = false;
  bool _spinCompleted = false;
  int _selectedTaskIndex = 0;

  // Reroll tracking
  final Map<String, int> _rerollsUsed = {}; // player -> rerollCount

  // Assignments so far
  final Map<String, WheelTask> _assignments = {};

  // ListWheel Controller
  late FixedExtentScrollController _scrollController;
  late List<WheelTask> _availableTasksForCurrentPlayer;

  // Animation for Confetti & Neon flashing
  late AnimationController _confettiController;
  late AnimationController _neonFlashingController;
  final List<_ConfettiParticle> _particles = [];

  // Active Task popup show/hide
  bool _showTaskPopup = false;

  @override
  void initState() {
    super.initState();
    _players = widget.playerNames.isEmpty ? ['Já'] : List.from(widget.playerNames);
    _scrollController = FixedExtentScrollController();

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addListener(() {
        if (_confettiController.isAnimating) {
          _updateParticles();
        }
      });

    _neonFlashingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _prepareTasksForCurrentPlayer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _confettiController.dispose();
    _neonFlashingController.dispose();
    super.dispose();
  }

  void _prepareTasksForCurrentPlayer() {
    final player = _players[_currentPlayerIndex];
    final history = widget.playerHistory[player] ?? [];
    final alreadyAssignedInThisTurn = _assignments.values.map((t) => t.id).toList();

    List<WheelTask> filtered = widget.wheel.tasks.where((task) {
      if (task.icon == 'luck') return true; // free pass is always allowed
      return !history.contains(task.id) && !alreadyAssignedInThisTurn.contains(task.id);
    }).toList();

    // Fallback if all tasks filtered out
    if (filtered.isEmpty) {
      filtered = widget.wheel.tasks.isNotEmpty
          ? widget.wheel.tasks
          : [
              WheelTask(
                id: 'fallback',
                title: 'Máš štěstí!',
                icon: 'luck',
                description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš.',
                exceptions: 'Žádné',
              )
            ];
    }

    setState(() {
      _availableTasksForCurrentPlayer = filtered;
      _spinCompleted = false;
      _showTaskPopup = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpToItem(0);
      }
    });
  }

  Future<void> _startSpin() async {
    if (_isSpinning) return;

    setState(() {
      _isSpinning = true;
      _spinCompleted = false;
      _showTaskPopup = false;
    });

    final random = math.Random();
    // Spin through at least 25-40 items for animation duration
    final spinCount = 25 + random.nextInt(15);

    try {
      // Faster neon flashing during spin
      _neonFlashingController.duration = const Duration(milliseconds: 150);
      _neonFlashingController.repeat(reverse: true);

      await _scrollController.animateToItem(
        spinCount,
        duration: const Duration(milliseconds: 3500),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // safe fallback
    }

    final finalIndex = _scrollController.selectedItem % _availableTasksForCurrentPlayer.length;

    // Slow neon flashing back
    _neonFlashingController.duration = const Duration(milliseconds: 600);
    _neonFlashingController.repeat(reverse: true);

    setState(() {
      _selectedTaskIndex = finalIndex;
      _isSpinning = false;
      _spinCompleted = true;
      _showTaskPopup = true;
    });

    _assignments[_players[_currentPlayerIndex]] = _availableTasksForCurrentPlayer[finalIndex];
    _triggerConfetti();
    HapticFeedback.heavyImpact();
  }

  void _triggerConfetti() {
    _particles.clear();
    final random = math.Random();
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        x: 0.5,
        y: 0.35,
        vx: (random.nextDouble() - 0.5) * 15,
        vy: (random.nextDouble() - 0.7) * 15 - 5,
        radius: random.nextDouble() * 5 + 4,
      ));
    }
    _confettiController.forward(from: 0.0);
  }

  void _updateParticles() {
    setState(() {
      for (var p in _particles) {
        p.x += p.vx * 0.016;
        p.y += p.vy * 0.016;
        p.vy += 9.8 * 0.016 * 10; // gravity
      }
    });
  }

  void _useReroll() {
    final player = _players[_currentPlayerIndex];
    final currentRerolls = _rerollsUsed[player] ?? 0;
    if (currentRerolls >= 1) return; // limit reached

    setState(() {
      _rerollsUsed[player] = currentRerolls + 1;
      _assignments.remove(player);
      _spinCompleted = false;
      _showTaskPopup = false;
    });

    _startSpin();
  }

  void _confirmAndNext() {
    if (_currentPlayerIndex < _players.length - 1) {
      setState(() {
        _currentPlayerIndex++;
      });
      _prepareTasksForCurrentPlayer();
    } else {
      widget.onComplete(_assignments);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _players[_currentPlayerIndex];
    final hasReroll = (_rerollsUsed[player] ?? 0) < 1;

    return Scaffold(
      backgroundColor: const Color(0xFF161C20),
      appBar: AppBar(
        title: const Text(
          'Kolo štěstí',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background glow
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.3,
                  colors: [
                    Color(0xFF263238),
                    Color(0xFF101417),
                  ],
                ),
              ),
            ),
          ),

          // Main slot machine screen layout wrapped to be fully responsive
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double screenHeight = constraints.maxHeight;
                final bool isShortScreen = screenHeight < 580;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top header stating which player is spinning
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF263238).withOpacity(0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBFFF00), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFBFFF00).withOpacity(0.08),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_outline_rounded, color: Color(0xFFBFFF00)),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Točí se pro: $player',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: isShortScreen ? 12 : 24),

                          // Cylinder interactive wheel
                          Center(
                            child: AnimatedBuilder(
                              animation: _neonFlashingController,
                              builder: (context, child) {
                                final flashColor = Color.lerp(
                                  const Color(0xFFBFFF00),
                                  const Color(0xFF1B5E20),
                                  _neonFlashingController.value,
                                )!;
                                return Container(
                                  constraints: BoxConstraints(maxHeight: isShortScreen ? 200 : 260),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(color: flashColor, width: 3.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: flashColor.withOpacity(0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Swipe gesture recognizer wrapped inside to trigger spin
                                        GestureDetector(
                                          onVerticalDragEnd: (details) {
                                            if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 200) {
                                              _startSpin();
                                            }
                                          },
                                          child: ListWheelScrollView.useDelegate(
                                            controller: _scrollController,
                                            itemExtent: 110,
                                            perspective: 0.004,
                                            diameterRatio: 1.6,
                                            physics: const NeverScrollableScrollPhysics(), // programmatically animate
                                            onSelectedItemChanged: (index) {
                                              HapticFeedback.selectionClick();
                                            },
                                            childDelegate: ListWheelChildLoopingListDelegate(
                                              children: _availableTasksForCurrentPlayer.map((task) {
                                                return Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF263238).withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    child: TaskDoodleWidget(iconCode: task.icon),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),

                                        // Overlay center winning line
                                        IgnorePointer(
                                          child: Container(
                                            height: 110,
                                            decoration: BoxDecoration(
                                              border: Border.symmetric(
                                                horizontal: BorderSide(color: const Color(0xFFBFFF00).withOpacity(0.7), width: 2.5),
                                              ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  const Color(0xFFBFFF00).withOpacity(0.04),
                                                  Colors.transparent,
                                                  const Color(0xFFBFFF00).withOpacity(0.04),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          SizedBox(height: isShortScreen ? 12 : 24),

                          // Action layout
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_isSpinning && !_spinCompleted)
                                ElevatedButton.icon(
                                  onPressed: _startSpin,
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.black),
                                  label: const Text('ROZTOČIT KOLO', style: TextStyle(fontWeight: FontWeight.w900)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFBFFF00),
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 4,
                                  ),
                                ),
                              if (_isSpinning)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF263238).withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFBFFF00)),
                                      ),
                                      SizedBox(width: 14),
                                      Text(
                                        'Hledám úkol...',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_spinCompleted && _showTaskPopup) _buildSelectedTaskCard(hasReroll),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Custom Confetti canvas
          if (_confettiController.isAnimating)
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedTaskCard(bool hasReroll) {
    final task = _availableTasksForCurrentPlayer[_selectedTaskIndex];
    final isLuck = task.icon == 'luck';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF263238),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isLuck ? const Color(0xFFBFFF00) : Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLuck ? const Color(0xFFBFFF00) : Colors.white12,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLuck ? Icons.emoji_events_rounded : Icons.assignment_turned_in_rounded,
                  color: isLuck ? Colors.black : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLuck ? 'VELKÝ BONUS!' : 'VYLOSEVANÝ ÚKOL',
                      style: TextStyle(
                        color: isLuck ? const Color(0xFFBFFF00) : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      task.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.description,
            style: const TextStyle(color: Colors.white90, fontSize: 13.5, height: 1.45),
          ),
          if (task.exceptions.isNotEmpty && task.exceptions != 'Žádné') ...[
            const SizedBox(height: 10),
            Text(
              '⚠️ Výjimky: ${task.exceptions}',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              if (hasReroll && !isLuck) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _useReroll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('PŘETOČIT ÚKOL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmAndNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBFFF00),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    _currentPlayerIndex < _players.length - 1 ? 'DALŠÍ HRÁČ' : 'POTVRDIT ÚKOL',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfettiParticle {
  Color color;
  double x;
  double y;
  double vx;
  double vy;
  double radius;

  _ConfettiParticle({
    required this.color,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      final double screenX = p.x * size.width;
      final double screenY = p.y * size.height;
      if (screenX < 0 || screenX > size.width || screenY > size.height) continue;
      paint.color = p.color;
      canvas.drawCircle(Offset(screenX, screenY), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
