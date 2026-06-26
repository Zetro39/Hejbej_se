import 'package:flutter/material.dart';

class TutorialStep {
  final int tabIndex;
  final String title;
  final String description;
  final bool showSpotlight;

  TutorialStep({
    required this.tabIndex,
    required this.title,
    required this.description,
    this.showSpotlight = true,
  });
}

class AppTutorialOverlay extends StatefulWidget {
  final Function(int) onTabChange;
  final VoidCallback onFinish;

  const AppTutorialOverlay({
    super.key,
    required this.onTabChange,
    required this.onFinish,
  });

  @override
  State<AppTutorialOverlay> createState() => _AppTutorialOverlayState();
}

class _AppTutorialOverlayState extends State<AppTutorialOverlay> {
  int _currentStep = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      tabIndex: 2,
      title: 'Vítej v Hejbej se! 👋',
      description: 'Tato aplikace tě motivuje k pohybu! Projdeme si společně hlavní obrazovky, abys věděl, jak vše funguje.',
      showSpotlight: false,
    ),
    TutorialStep(
      tabIndex: 2,
      title: 'Mapa & Trasy 🗺️',
      description: 'Zde vidíš svou aktuální polohu. Můžeš si vygenerovat trasy na míru a sledovat svůj denní pohyb na mapě.',
      showSpotlight: true,
    ),
    TutorialStep(
      tabIndex: 0,
      title: 'Hry & Výzvy 🏆',
      description: 'Sleduj své denní kroky, plň úkoly v Cestě živlů nebo vyzvi přátele na souboj v krocích!',
      showSpotlight: true,
    ),
    TutorialStep(
      tabIndex: 3,
      title: 'Žebříček & Sběratelé 🥇',
      description: 'Soutěž v nachozených kilometrech s celou ČR, krajem nebo přáteli. A nezapomeň se zapojit do žebříčku Sběratelů úspěchů!',
      showSpotlight: true,
    ),
    TutorialStep(
      tabIndex: 4,
      title: 'Obchod 🛍️',
      description: 'Za nachozené kilometry získáváš limetky, za které si v obchodě koupíš nové avatary a doprovodné společníky.',
      showSpotlight: true,
    ),
    TutorialStep(
      tabIndex: 1,
      title: 'Tvůj Profil 👤',
      description: 'Sleduj své dlouhodobé statistiky, měň companiony a plň 30 unikátních úspěchů, za které získáš prestiž a odměny!',
      showSpotlight: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Set initial tab index to matching first step (tabIndex 2, which is Map)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTabChange(_steps[_currentStep].tabIndex);
    });
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      widget.onTabChange(_steps[_currentStep].tabIndex);
    } else {
      widget.onFinish();
    }
  }

  int _getNavPosition(int tabIndex) {
    switch (tabIndex) {
      case 0: return 0; // Hry
      case 3: return 1; // Žebříček
      case 2: return 2; // Mapa (Center)
      case 4: return 3; // Obchod
      case 1: return 4; // Profil
      default: return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = mediaQuery.padding.bottom;
    
    // Bottom bar height is 72 + bottom padding
    final double bottomBarCenterY = screenHeight - bottomPadding - 36;
    final double buttonWidth = screenWidth / 5;
    
    final int navPosIndex = _getNavPosition(step.tabIndex);
    final double spotlightCenterX = (navPosIndex + 0.5) * buttonWidth;

    return Stack(
      children: [
        // Custom Painter for spotlight
        Positioned.fill(
          child: CustomPaint(
            painter: SpotlightPainter(
              targetOffset: Offset(spotlightCenterX, bottomBarCenterY),
              radius: 36.0,
              showSpotlight: step.showSpotlight,
            ),
          ),
        ),
        
        // Prevents interaction with background during walkthrough
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // consume tap
          ),
        ),

        // Dialog card layout
        Positioned(
          left: 20,
          right: 20,
          bottom: step.showSpotlight ? bottomPadding + 96 : null,
          top: step.showSpotlight ? null : screenHeight * 0.35,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E272C),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFBFFF00).withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_currentStep + 1}/${_steps.length}',
                        style: const TextStyle(
                          color: Color(0xFFBFFF00),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.87),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: widget.onFinish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: const Text('Přeskočit', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFFF00),
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          _currentStep == _steps.length - 1 ? 'Začít' : 'Pokračovat',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Offset targetOffset;
  final double radius;
  final bool showSpotlight;

  SpotlightPainter({
    required this.targetOffset,
    required this.radius,
    required this.showSpotlight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Save current layer
    canvas.saveLayer(Offset.zero & size, Paint());

    // Draw solid semi-transparent backdrop
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.75);
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    if (showSpotlight) {
      // Clear a circular hole for the target button
      final clearPaint = Paint()..blendMode = BlendMode.clear;
      canvas.drawCircle(targetOffset, radius, clearPaint);

      // Draw a subtle neon border around the spotlight hole
      final borderPaint = Paint()
        ..color = const Color(0xFFBFFF00)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(targetOffset, radius + 1, borderPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetOffset != targetOffset ||
        oldDelegate.radius != radius ||
        oldDelegate.showSpotlight != showSpotlight;
  }
}
