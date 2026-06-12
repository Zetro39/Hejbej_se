import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_quest_model.dart';
import '../services/story_game_service.dart';
import 'point_and_click_screen.dart';
import 'logic_puzzles_screen.dart';
import 'catching_game_screen.dart';
import 'story_animations.dart';
import 'package:audioplayers/audioplayers.dart';

class StoryMapScreen extends StatefulWidget {
  const StoryMapScreen({super.key});

  @override
  State<StoryMapScreen> createState() => _StoryMapScreenState();
}

class _StoryMapScreenState extends State<StoryMapScreen> {
  final StoryGameService _service = StoryGameService();
  bool _showIntro = false;
  int _introSlideIndex = 0;
  final AudioPlayer _musicPlayer = AudioPlayer();
  late ScrollController _scrollController;

  // Debug coordinate panel and path drawing tool variables
  bool _showDebugCoords = false;
  Offset? _debugMapTap;
  int _selectedDebugSegment = 0; // 0 to 4
  final Map<String, List<Offset>> _debugDraftPaths = {
    'node1_node2': [],
    'node2_node3': [],
    'node3_node4': [],
    'node4_node5': [],
    'node5_node6': [],
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _service.initialize();
    _checkIntro();
    _initMusic();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _initMusic() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(0.12); // Low volume background music
      await _musicPlayer.play(AssetSource('ambient_bg.mp3'));
    } catch (_) {}
  }

  @override
  void dispose() {
    _musicPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('story_intro_shown') ?? false;
    if (!shown) {
      setState(() {
        _showIntro = true;
      });
    }
  }

  void _closeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('story_intro_shown', true);
    setState(() {
      _showIntro = false;
    });
  }

  Widget _buildIntroSlide() {
    final titles = [
      'Prastará legenda',
      'Pád rovnováhy',
      'Tvá cesta',
    ];

    final texts = [
      'Podle pověstí našich předků střežily české pohraniční lesy čtyři posvátné elementy: Oheň, Voda, Země a Vzduch. Tyto elementy udržovaly přírodu v harmonii a byly svázány v mocném Amuletu rovnováhy.',
      'Před sto lety však byla starobylá pevnost, ve které byl amulet střežen, napadena a zničena. Amulet se vybil a ztratil se v divočině. Od té doby lesy chřadnou, studánky vysychají a zvěř ztrácí klid.',
      'Ty, jakožto odhodlaný mladý cestovatel, jsi v archivech objevil starodávnou mapu stezky. Tvým posláním je ujít trasu o délce 6 kilometrů, najít vyhaslý amulet, sesbírat a očistit všechny 4 elementy a na Kamenném oltáři amulet znovu zažehnout. Osud lesů leží ve tvých rukou!',
    ];

    final bgAssets = [
      'assets/images/story_room_altar.png',
      'assets/images/story_room_fortress_exterior.png',
      'assets/images/story_room_gate_closed.png',
    ];

    final isAdventurerSlide = _introSlideIndex == 2;

    return Stack(
      children: [
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.darken,
            ),
            child: Image.asset(
              bgAssets[_introSlideIndex],
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (isAdventurerSlide)
          Positioned(
            right: 8,
            bottom: 40,
            width: 170,
            height: 340,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                1, 0, 0, 0, 0,
                0, 1, 0, 0, 0,
                0, 0, 1, 0, 0,
                -1, -1, -1, 3, 0,
              ]),
              child: Image.asset(
                'assets/images/story_player_adventurer.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
              ),
            ),
          ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 28.0, right: 28.0, bottom: 140.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_introSlideIndex],
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 12, offset: Offset(0, 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Text(
                    texts[_introSlideIndex],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntroWidget() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Background Slide Content
          Positioned.fill(
            child: _buildIntroSlide(),
          ),
          
          // Cinematic Vignette Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.25, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Weather particles for cinematic effect
          const Positioned.fill(
            child: ImmersiveWeatherParticles(particleType: 'leaves'),
          ),

          // Header Skip Action
          Positioned(
            top: 40,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PROLOG VÝPRAVY',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                TextButton(
                  onPressed: _closeIntro,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black45,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Přeskočit ▷', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ],
            ),
          ),

          // Navigation and Dots
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    final isActive = index == _introSlideIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.cyanAccent : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_introSlideIndex > 0)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Colors.white24, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            _introSlideIndex--;
                          });
                        },
                        child: const Row(
                           children: [
                             Icon(Icons.arrow_back_ios, size: 14),
                             SizedBox(width: 4),
                             Text('Zpět', style: TextStyle(fontWeight: FontWeight.bold)),
                           ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.shade700,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Colors.cyanAccent, width: 1),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      onPressed: () {
                        if (_introSlideIndex < 2) {
                          setState(() {
                            _introSlideIndex++;
                          });
                        } else {
                          _closeIntro();
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            _introSlideIndex == 2 ? 'Zahájit výpravu' : 'Pokračovat',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Offset _getAvatarPosition(int walkedMeters) {
    if (_service.nodes.isEmpty) return const Offset(0.5, 0.5);
    
    if (walkedMeters <= 0) return _service.nodes.first.mapPosition;
    if (walkedMeters >= _service.nodes.last.requiredDistance) {
      return _service.nodes.last.mapPosition;
    }

    // Find current segment
    QuestNode nodeA = _service.nodes.first;
    QuestNode nodeB = _service.nodes.last;

    for (int i = 0; i < _service.nodes.length - 1; i++) {
      final a = _service.nodes[i];
      final b = _service.nodes[i + 1];
      if (walkedMeters >= a.requiredDistance && walkedMeters < b.requiredDistance) {
        nodeA = a;
        nodeB = b;
        break;
      }
    }

    // Get segment path
    final pathPoints = _service.getFullSegmentPath(nodeA, nodeB);

    // Interpolate
    double segmentTotal = (nodeB.requiredDistance - nodeA.requiredDistance).toDouble();
    double segmentProgress = (walkedMeters - nodeA.requiredDistance) / (segmentTotal > 0 ? segmentTotal : 1.0);

    return _interpolatePositionAlongPath(pathPoints, segmentProgress);
  }

  Offset _interpolatePositionAlongPath(List<Offset> points, double progress) {
    if (points.isEmpty) return const Offset(0.5, 0.5);
    if (points.length == 1) return points.first;
    if (progress <= 0.0) return points.first;
    if (progress >= 1.0) return points.last;

    // 1. Calculate lengths of all sub-segments
    List<double> subLengths = [];
    double totalLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final length = (points[i+1] - points[i]).distance;
      subLengths.add(length);
      totalLength += length;
    }

    if (totalLength == 0) return points.first;

    // 2. Find target length along the polyline
    double targetLength = progress * totalLength;

    // 3. Find which sub-segment targetLength falls into
    double accumulatedLength = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      final length = subLengths[i];
      if (targetLength <= accumulatedLength + length) {
        double localProgress = (targetLength - accumulatedLength) / (length > 0 ? length : 1.0);
        return Offset(
          points[i].dx + (points[i+1].dx - points[i].dx) * localProgress,
          points[i].dy + (points[i+1].dy - points[i].dy) * localProgress,
        );
      }
      accumulatedLength += length;
    }

    return points.last;
  }

  void _showLockedProgressAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🔒 Cesta blokována', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }

  void _autoAdvance(QuestNode completedNode) {
    final nextNodeIndex = _service.nodes.indexWhere((n) => n.id == completedNode.id) + 1;
    if (nextNodeIndex < _service.nodes.length) {
      final nextNode = _service.nodes[nextNodeIndex];
      final latestState = _service.stateNotifier.value;
      
      // Delay to allow the screen transition back to map to finish
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _showNextNodePreviewDialog(nextNode, latestState);
        }
      });
    }
  }

  void _onNodeTap(QuestNode node, QuestState state) {
    // If it's already completed, let them enter directly
    if (state.completedNodes.contains(node.id)) {
      _enterNode(node, state);
      return;
    }
    // Show preview/unlock dialog
    _showNextNodePreviewDialog(node, state);
  }

  void _enterNode(QuestNode node, QuestState state) {
    // Striktní sekvenční průchod hrou
    if (node.id == 'node2' && !state.completedNodes.contains('node1')) {
      _showLockedProgressAlert("Musíš nejprve otevřít Lesní bránu (Lokace 1) a projít skrz ni.");
      return;
    }
    if (node.id == 'node3' && !state.completedNodes.contains('node2')) {
      _showLockedProgressAlert("Musíš nejprve vyřešit hádanku u Starého dubu (Lokace 2).");
      return;
    }
    if (node.id == 'node4' && !state.completedNodes.contains('node3')) {
      _showLockedProgressAlert("Musíš nejprve kompletně prozkoumat Zříceninu chýše (Lokace 3).");
      return;
    }
    if (node.id == 'node5' && !state.completedNodes.contains('node4')) {
      _showLockedProgressAlert("Musíš nejprve pomoci Poustevníkovi v bažině a uzdravit ho (Lokace 4).");
      return;
    }
    if (node.id == 'node6' && !state.completedNodes.contains('node5')) {
      _showLockedProgressAlert("Musíš nejprve seřídit dalekohled v pevnosti (Lokace 5).");
      return;
    }

    // Navigate to location screen
    if (node.id == 'node1' || node.id == 'node2' || node.id == 'node3') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id),
        ),
      ).then((didSolve) {
        if (didSolve == true) {
          _autoAdvance(node);
        }
      });
    } else if (node.id == 'node4') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id),
        ),
      ).then((didSolve) {
        if (didSolve == true) {
          _autoAdvance(node);
        }
      });
    } else if (node.id == 'node5') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id),
        ),
      ).then((didSolve) {
        if (didSolve == true) {
          _autoAdvance(node);
        }
      });
    } else if (node.id == 'node6') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id),
        ),
      ).then((didSolve) {
        if (didSolve == true) {
          _autoAdvance(node);
        }
      });
    }
  }

  void _showNextNodePreviewDialog(QuestNode node, QuestState state) {
    final nextNodeImg = {
      'node1': 'assets/images/story_room_gate_closed.png',
      'node2': 'assets/images/story_room_oak.png',
      'node3': 'assets/images/story_room_cabin_exterior.png',
      'node4': 'assets/images/story_room_swamp.png',
      'node5': 'assets/images/story_room_fortress_exterior.png',
      'node6': 'assets/images/story_room_altar.png',
    }[node.id] ?? 'assets/images/story_room_gate_closed.png';

    final isUnlocked = state.unlockedNodes.contains(node.id);
    final neededDistance = node.requiredDistance - state.currentDistanceWalked;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 20, left: 24, right: 50, bottom: 10),
              child: Text(
                node.name,
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            Positioned(
              right: 12,
              top: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                nextNodeImg,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            if (isUnlocked) ...[
              const Text(
                "Tato lokace je odemčená! Můžeš vstoupit a začít hrát.",
                style: TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Text(
                "Tato lokace je prozatím uzamčena.",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Musíš ujít ještě: ${neededDistance.toInt()} metrů.",
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.only(bottom: 16, right: 24, left: 24),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zavřít', style: TextStyle(color: Colors.white70)),
              ),
              if (isUnlocked)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _enterNode(node, state);
                  },
                  child: const Text('Pokračovat', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showIntro) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildIntroWidget(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<QuestState>(
        valueListenable: _service.stateNotifier,
        builder: (context, state, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final mapWidth = constraints.maxWidth;
              final mapHeight = constraints.maxHeight;
              final avatarPos = _getAvatarPosition(state.currentDistanceWalked);

              return Stack(
                children: [
                  // Map Background & Interactive Area scaled together to avoid coordinate drift
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      controller: _scrollController,
                      child: Center(
                        child: SizedBox(
                          width: mapWidth,
                          height: mapWidth * (3234 / 1080),
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: 1080,
                              height: 3234,
                              child: Stack(
                                children: [
                                  // Map Background Image with coordinate debug detector
                                  Positioned.fill(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTapUp: (details) {
                                        if (_showDebugCoords) {
                                          final double tapX = details.localPosition.dx / 1080;
                                          final double tapY = details.localPosition.dy / 3234;
                                          setState(() {
                                            _debugMapTap = Offset(tapX, tapY);
                                            // Add to active draft path
                                            final key = [
                                              'node1_node2',
                                              'node2_node3',
                                              'node3_node4',
                                              'node4_node5',
                                              'node5_node6',
                                            ][_selectedDebugSegment];
                                            _debugDraftPaths[key]?.add(Offset(tapX, tapY));
                                          });
                                        }
                                      },
                                      child: Image.asset(
                                        'assets/images/story_map.png',
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  ),

                                  // Overlay fog for locked chapters
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.05), // subtle dark overlay
                                    ),
                                  ),

                                  // Custom Painter to draw paths
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _MapPathPainter(
                                        nodes: _service.nodes,
                                        walkedDistance: state.currentDistanceWalked,
                                        unlockedNodes: state.unlockedNodes,
                                        service: _service,
                                        showDebugCoords: _showDebugCoords,
                                        debugDraftPaths: _debugDraftPaths,
                                        selectedDebugSegment: _selectedDebugSegment,
                                      ),
                                    ),
                                  ),

                                  // Render nodes (Locations)
                                  ..._service.nodes.map((node) {
                                    final isUnlocked = state.unlockedNodes.contains(node.id);
                                    final isCompleted = state.completedNodes.contains(node.id);
                                    final posX = node.mapPosition.dx * 1080;
                                    final posY = node.mapPosition.dy * 3234;

                                    return Positioned(
                                      left: posX - 28,
                                      top: posY - 28,
                                      child: GestureDetector(
                                        onTap: () => _onNodeTap(node, state),
                                        child: _buildNodeMarker(node, isUnlocked, isCompleted),
                                      ),
                                    );
                                  }),

                                  // User Avatar marker
                                  Positioned(
                                    left: (avatarPos.dx * 1080) - 20,
                                    top: (avatarPos.dy * 3234) - 35,
                                    child: IgnorePointer(
                                      child: AnimatedBobbingWidget(
                                        child: _buildAvatarMarker(),
                                      ),
                                    ),
                                  ),

                                  // Debug tap red dot (last tapped)
                                  if (_showDebugCoords && _debugMapTap != null)
                                    Positioned(
                                      left: (_debugMapTap!.dx * 1080) - 12,
                                      top: (_debugMapTap!.dy * 3234) - 12,
                                      child: IgnorePointer(
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.9),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: const [
                                              BoxShadow(color: Colors.black45, blurRadius: 4)
                                            ],
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.location_searching, color: Colors.white, size: 12),
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
                    ),
                  ),

                  // Sleek integrated floating HUD at the top (KM progress + actions)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left: Exit Button + Capsule showing progress and inventory
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFloatingRoundButton(
                                  icon: Icons.arrow_back,
                                  tooltip: 'Zpět do aplikace',
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.directions_walk, color: Colors.cyanAccent, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${(state.currentDistanceWalked / 1000).toStringAsFixed(2)} km / 6.00 km',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                          shadows: [
                                            Shadow(color: Colors.black, blurRadius: 4),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 1.5,
                                        height: 14,
                                        color: Colors.white24,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '🎒 ${state.inventory.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Right: Sleek round action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFloatingRoundButton(
                                  icon: _showDebugCoords ? Icons.location_searching : Icons.location_disabled,
                                  tooltip: 'Ladění souřadnic',
                                  onTap: () {
                                    setState(() {
                                      _showDebugCoords = !_showDebugCoords;
                                      if (!_showDebugCoords) {
                                        _debugMapTap = null;
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildFloatingRoundButton(
                                  icon: Icons.menu_book,
                                  tooltip: 'Zobrazit prolog',
                                  onTap: () {
                                    setState(() {
                                      _showIntro = true;
                                      _introSlideIndex = 0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 10),
                                _buildFloatingRoundButton(
                                  icon: Icons.refresh,
                                  tooltip: 'Restartovat příběh',
                                  onTap: _showRestartDialog,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Floating Debug Coordinates Panel
                  if (_showDebugCoords)
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 80, // Leave space for simulation buttons on the right!
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E24).withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "🛠️ EDITOR TRAS",
                                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.cyanAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "Bodů: ${_debugDraftPaths[['node1_node2', 'node2_node3', 'node3_node4', 'node4_node5', 'node5_node6'][_selectedDebugSegment]]?.length ?? 0}",
                                    style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Segment selector dropdown
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedDebugSegment,
                                  dropdownColor: const Color(0xFF1E1E24),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text("Segment 1: Brána ➔ Dub")),
                                    DropdownMenuItem(value: 1, child: Text("Segment 2: Dub ➔ Chýše")),
                                    DropdownMenuItem(value: 2, child: Text("Segment 3: Chýše ➔ Bažina")),
                                    DropdownMenuItem(value: 3, child: Text("Segment 4: Bažina ➔ Pevnost")),
                                    DropdownMenuItem(value: 4, child: Text("Segment 5: Pevnost ➔ Oltář")),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedDebugSegment = val;
                                        _debugMapTap = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_debugMapTap != null) ...[
                              Text(
                                "Poslední bod: x: ${_debugMapTap!.dx.toStringAsFixed(4)}, y: ${_debugMapTap!.dy.toStringAsFixed(4)}",
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Actions Row
                            Row(
                              children: [
                                // Undo Button
                                Expanded(
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white10,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.undo, size: 14),
                                    label: const Text("Zpět", style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      final key = [
                                        'node1_node2',
                                        'node2_node3',
                                        'node3_node4',
                                        'node4_node5',
                                        'node5_node6',
                                      ][_selectedDebugSegment];
                                      final list = _debugDraftPaths[key];
                                      if (list != null && list.isNotEmpty) {
                                        setState(() {
                                          list.removeLast();
                                          _debugMapTap = list.isNotEmpty ? list.last : null;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // Clear Button
                                Expanded(
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.red.withOpacity(0.15),
                                      foregroundColor: Colors.redAccent,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    icon: const Icon(Icons.delete_outline, size: 14),
                                    label: const Text("Smazat", style: TextStyle(fontSize: 11)),
                                    onPressed: () {
                                      final key = [
                                        'node1_node2',
                                        'node2_node3',
                                        'node3_node4',
                                        'node4_node5',
                                        'node5_node6',
                                      ][_selectedDebugSegment];
                                      setState(() {
                                        _debugDraftPaths[key]?.clear();
                                        _debugMapTap = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Copy Button (primary action)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text("KOPÍROVAT BODY", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                final key = [
                                  'node1_node2',
                                  'node2_node3',
                                  'node3_node4',
                                  'node4_node5',
                                  'node5_node6',
                                ];
                                final activeKey = key[_selectedDebugSegment];
                                final points = _debugDraftPaths[activeKey] ?? [];
                                if (points.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("Trasa neobsahuje žádné body k zkopírování.")),
                                  );
                                  return;
                                }
                                final pointsStr = points.map((p) => "const Offset(${p.dx.toStringAsFixed(4)}, ${p.dy.toStringAsFixed(4)})").join(",\n");
                                final formatted = "'$activeKey': [\n$pointsStr\n],";
                                Clipboard.setData(ClipboardData(text: formatted));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Souřadnice segmentu $activeKey zkopírovány do schránky!")),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Helper test button to simulate walking (ONLY FOR CONVENIENCE FOR USER TESTING)
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'skip_walk',
                          backgroundColor: Colors.red.shade800,
                          foregroundColor: Colors.white,
                          onPressed: () => _service.addMeters(6000),
                          tooltip: 'Přeskočit veškerou chůzi (K1 - K6)',
                          child: const Icon(Icons.fast_forward),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Přeskočit\nchůzi',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        FloatingActionButton.small(
                          heroTag: 'walk_100',
                          backgroundColor: Colors.lime.shade800,
                          foregroundColor: Colors.white,
                          onPressed: () => _service.addMeters(200),
                          tooltip: 'Simulovat +200 metrů chůze',
                          child: const Icon(Icons.add_road),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Simulovat\n+200 m',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, shadows: [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ]),
                        )
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFloatingRoundButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Restartovat výpravu?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Tímto smažeš veškerý svůj dosavadní pokrok, předměty a budeš muset začít od nuly. Přejete si pokračovat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušit', style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () async {
              await _service.resetQuest();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Restartovat'),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeMarker(QuestNode node, bool isUnlocked, bool isCompleted) {
    Color ringColor = Colors.grey;
    Color bgColor = Colors.grey.shade300;
    Widget icon = const Icon(Icons.lock, color: Colors.grey, size: 20);

    if (isUnlocked) {
      if (isCompleted) {
        ringColor = Colors.lime.shade600;
        bgColor = Colors.lime.shade100;
        icon = const Icon(Icons.check, color: Colors.green, size: 24);
      } else {
        ringColor = Colors.lightBlue;
        bgColor = Colors.white;
        icon = const Icon(Icons.location_on, color: Colors.lightBlue, size: 24);
      }
    }

    return Tooltip(
      message: '${node.name}\n${node.requiredDistance}m',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 3),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              node.name,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAvatarMarker() {
    return Container(
      width: 40,
      height: 45,
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 3)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Marker Pin base
          const Icon(Icons.location_on, color: Colors.orange, size: 42),
          // Character miniature
          Positioned(
            top: 4,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: Image.asset(
                  'assets/images/bear.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _MapPathPainter extends CustomPainter {
  final List<QuestNode> nodes;
  final int walkedDistance;
  final List<String> unlockedNodes;
  final StoryGameService service;
  final bool showDebugCoords;
  final Map<String, List<Offset>> debugDraftPaths;
  final int selectedDebugSegment;

  _MapPathPainter({
    required this.nodes,
    required this.walkedDistance,
    required this.unlockedNodes,
    required this.service,
    required this.showDebugCoords,
    required this.debugDraftPaths,
    required this.selectedDebugSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodes.length < 2) return;

    final paintCompleted = Paint()
      ..color = Colors.lime.shade600
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintLocked = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintDebugPath = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintDebugPoint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    // 1. Draw segment lines (using polyline paths from service)
    for (int i = 0; i < nodes.length - 1; i++) {
      final nodeA = nodes[i];
      final nodeB = nodes[i + 1];

      final pathPoints = service.getFullSegmentPath(nodeA, nodeB);
      final pixelPoints = pathPoints.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();
      final isSegmentCompleted = unlockedNodes.contains(nodeB.id);

      if (isSegmentCompleted) {
        for (int j = 0; j < pixelPoints.length - 1; j++) {
          canvas.drawLine(pixelPoints[j], pixelPoints[j + 1], paintCompleted);
        }
      } else {
        for (int j = 0; j < pixelPoints.length - 1; j++) {
          _drawDashedLine(canvas, pixelPoints[j], pixelPoints[j + 1], paintLocked);
        }
      }
    }

    // 2. Draw debug draft paths if debug mode is active
    if (showDebugCoords) {
      for (int i = 0; i < nodes.length - 1; i++) {
        final nodeA = nodes[i];
        final nodeB = nodes[i + 1];
        final key = "${nodeA.id}_${nodeB.id}";
        final draftPoints = debugDraftPaths[key] ?? [];

        if (draftPoints.isNotEmpty) {
          final isSelected = selectedDebugSegment == i;
          final draftPaint = isSelected 
              ? (Paint()
                  ..color = Colors.yellowAccent
                  ..strokeWidth = 5.0
                  ..strokeCap = StrokeCap.round
                  ..style = PaintingStyle.stroke)
              : paintDebugPath;

          final pixelPoints = [
            nodeA.mapPosition, 
            ...draftPoints, 
            nodeB.mapPosition
          ].map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

          // Draw connections
          for (int j = 0; j < pixelPoints.length - 1; j++) {
            canvas.drawLine(pixelPoints[j], pixelPoints[j + 1], draftPaint);
          }

          // Draw circles for draft points
          for (int j = 1; j < pixelPoints.length - 1; j++) {
            canvas.drawCircle(pixelPoints[j], 6.0, paintDebugPoint);
            
            // Draw text index
            final textPainter = TextPainter(
              text: TextSpan(
                text: "$j",
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(pixelPoints[j].dx - 3, pixelPoints[j].dy - 14));
          }
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 8.0;
    const double dashSpace = 6.0;

    double dx = p2.dx - p1.dx;
    double dy = p2.dy - p1.dy;
    double distance = Offset(dx, dy).distance;

    int dashCount = (distance / (dashWidth + dashSpace)).floor();

    double xStep = dx / distance;
    double yStep = dy / distance;

    for (int i = 0; i < dashCount; i++) {
      double startOffset = i * (dashWidth + dashSpace);
      double endOffset = startOffset + dashWidth;

      canvas.drawLine(
        Offset(p1.dx + xStep * startOffset, p1.dy + yStep * startOffset),
        Offset(p1.dx + xStep * endOffset, p1.dy + yStep * endOffset),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MapPathPainter oldDelegate) {
    return oldDelegate.walkedDistance != walkedDistance ||
        oldDelegate.unlockedNodes.length != unlockedNodes.length ||
        oldDelegate.showDebugCoords != showDebugCoords ||
        oldDelegate.selectedDebugSegment != selectedDebugSegment ||
        oldDelegate.debugDraftPaths != debugDraftPaths;
  }
}
