import 'dart:math';
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

  // Animation for Confetti
  late AnimationController _confettiController;
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

    _prepareTasksForCurrentPlayer();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _prepareTasksForCurrentPlayer() {
    final player = _players[_currentPlayerIndex];
    final history = widget.playerHistory[player] ?? [];
    final alreadyAssignedInThisTurn = _assignments.values.map((t) => t.id).toList();

    // Filter tasks:
    // 1. Player hasn't completed them on this route before (history check).
    // 2. Not assigned to another player in this spin event (duplicity check).
    // Note: Free pass ('luck') can bypass these checks to ensure we never run out of tasks.
    List<WheelTask> filtered = widget.wheel.tasks.where((task) {
      if (task.icon == 'luck') return true; // free pass is always allowed
      return !history.contains(task.id) && !alreadyAssignedInThisTurn.contains(task.id);
    }).toList();

    // Fallback if all tasks filtered out
    if (filtered.isEmpty) {
      filtered = widget.wheel.tasks.isNotEmpty 
          ? widget.wheel.tasks 
          : [WheelTask(id: 'fallback', title: 'Máš štěstí!', icon: 'luck', description: 'Tento úsek jdeš bez jakéhokoliv úkolu a odpočíváš.', exceptions: 'Žádné')];
    }

    setState(() {
      _availableTasksForCurrentPlayer = filtered;
      _spinCompleted = false;
      _showTaskPopup = false;
    });

    // Reset scroll to 0
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

    final random = Random();
    // Spin through at least 20-30 items for animation duration
    final spinCount = 25 + random.nextInt(15);
    final targetIndex = spinCount % _availableTasksForCurrentPlayer.length;

    // Play ticking sound and vibration on each tick using custom scroll animation
    int lastItem = 0;
    try {
      await _scrollController.animateToItem(
        spinCount,
        duration: const Duration(milliseconds: 3500),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      // safe fallback if wheel gets interrupted
    }

    final finalIndex = _scrollController.selectedItem % _availableTasksForCurrentPlayer.length;

    setState(() {
      _selectedTaskIndex = finalIndex;
      _isSpinning = false;
      _spinCompleted = true;
      _showTaskPopup = true;
    });

    _assignments[_players[_currentPlayerIndex]] = _availableTasksForCurrentPlayer[finalIndex];

    // Trigger confetti if they spun anything, but especially if it's luck or a good roll
    _triggerConfetti();
  }

  void _triggerConfetti() {
    _particles.clear();
    final random = Random();
    for (int i = 0; i < 60; i++) {
      _particles.add(_ConfettiParticle(
        color: Colors.primaries[random.nextInt(Colors.primaries.length)],
        x: 0.5, // middle of screen
        y: 0.3, // top area
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
      // Complete! Return assignments to maps screen
      widget.onComplete(_assignments);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = _players[_currentPlayerIndex];
    final hasReroll = (_rerollsUsed[player] ?? 0) < 1;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1035), // Dark arcade theme purple
      appBar: AppBar(
        title: const Text('Automat úkolů trasy'),
        backgroundColor: Colors.purple.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background decorations / neon glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    const Color(0xFF3B1E6D),
                    const Color(0xFF100720),
                  ],
                ),
              ),
            ),
          ),

          // Main slot machine screen layout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top header stating which player is spinning
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade800.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purpleAccent, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: Colors.purpleAccent),
                      const SizedBox(width: 10),
                      Text(
                        'Točí se pro: $player',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Slot machine framing
                Expanded(
                  child: Center(
                    child: Container(
                      maxHeight: 280,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.amberAccent, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amberAccent.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 3D vertical reel
                            ListWheelScrollView.useDelegate(
                              controller: _scrollController,
                              itemExtent: 110,
                              perspective: 0.005,
                              diameterRatio: 1.8,
                              physics: const NeverScrollableScrollPhysics(), // we trigger programmatically
                              onSelectedItemChanged: (index) {
                                // play ticking sound and vibration on each item shift
                                HapticFeedback.selectionClick();
                              },
                              childDelegate: ListWheelChildLoopingListDelegate(
                                children: _availableTasksForCurrentPlayer.map((task) {
                                  return Center(
                                    child: TaskDoodleWidget(iconCode: task.icon),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Overlay center highlight borders (winning line)
                            IgnorePointer(
                              child: Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  border: Border.symmetric(
                                    horizontal: BorderSide(color: Colors.amberAccent.withOpacity(0.8), width: 3),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.amberAccent.withOpacity(0.05),
                                      Colors.transparent,
                                      Colors.amberAccent.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Spin action button
                if (!_isSpinning && !_spinCompleted)
                  ElevatedButton(
                    onPressed: _startSpin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Colors.black, width: 3),
                      ),
                      elevation: 8,
                      shadowColor: Colors.black,
                    ),
                    child: const Text(
                      'ZATOČIT',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  )
                else if (_isSpinning)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade900,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purpleAccent, width: 2),
                    ),
                    child: const Center(
                      child: Text(
                        'TOČÍ SE...',
                        style: TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 60), // spacer
              ],
            ),
          ),

          // Custom Confetti rendering
          if (_confettiController.isAnimating)
            IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_particles),
              ),
            ),

          // Popup layout displaying task details after spin stops
          if (_showTaskPopup && _spinCompleted)
            _buildTaskDetailPopup(hasReroll),
        ],
      ),
    );
  }


  /// Overlay detail popup showing winning task description
  Widget _buildTaskDetailPopup(bool hasReroll) {
    final task = _availableTasksForCurrentPlayer[_selectedTaskIndex];
    final player = _players[_currentPlayerIndex];

    // Format description text if placeholders exist
    String desc = task.description;
    if (desc.contains('{hráč}')) {
      final otherPlayers = _players.where((p) => p != player).toList();
      final target = otherPlayers.isNotEmpty ? otherPlayers[Random().nextInt(otherPlayers.length)] : 'Karád';
      desc = desc.replaceAll('{hráč}', target);
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              color: const Color(0xFF2E194F), // Arcade deep purple
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Colors.amberAccent, width: 4),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Visual icon badge
                    TaskDoodleWidget(iconCode: task.icon, size: 100),
                    const SizedBox(height: 20),

                    // Winner details
                    Text(
                      'ÚKOL PRO: $player',
                      style: TextStyle(
                        color: Colors.purpleAccent.shade100,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      task.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Jak úkol plnit:',
                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            desc,
                            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Výjimky a omezení:',
                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            task.exceptions,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        // Reroll option
                        if (hasReroll)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _useReroll,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const Text('PŘETOČIT 🃏', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.amberAccent,
                                side: const BorderSide(color: Colors.amberAccent, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade900.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.purple.shade800, width: 1.5),
                              ),
                              child: const Center(
                                child: Text(
                                  'REROLL VYČERPÁN 🃏',
                                  style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(width: 12),

                        // Confirmation
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _confirmAndNext,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.black, width: 2),
                              ),
                            ),
                            child: Text(
                              _currentPlayerIndex < _players.length - 1 ? 'DALŠÍ HRÁČ' : 'HOTOVO',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
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
      ),
    );
  }
}

class _ConfettiParticle {
  Color color;
  double x, y;
  double vx, vy;
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
  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      paint.color = p.color;
      final px = p.x * size.width;
      final py = p.y * size.height;
      if (px >= 0 && px <= size.width && py >= 0 && py <= size.height) {
        canvas.drawCircle(Offset(px, py), p.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
