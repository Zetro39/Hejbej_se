import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/story_quest_model.dart';
import '../services/story_game_service.dart';
import 'point_and_click_screen.dart';
import 'logic_puzzles_screen.dart';
import 'catching_game_screen.dart';

class StoryMapScreen extends StatefulWidget {
  const StoryMapScreen({super.key});

  @override
  State<StoryMapScreen> createState() => _StoryMapScreenState();
}

class _StoryMapScreenState extends State<StoryMapScreen> {
  final StoryGameService _service = StoryGameService();
  bool _showIntro = false;
  int _introSlideIndex = 0;

  @override
  void initState() {
    super.initState();
    _service.initialize();
    _checkIntro();
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
      'assets/images/story_player_adventurer.png',
    ];

    final isAdventurerSlide = _introSlideIndex == 2;

    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(isAdventurerSlide ? 0.85 : 0.65),
                BlendMode.darken,
              ),
              child: Image.asset(
                bgAssets[_introSlideIndex],
                fit: isAdventurerSlide ? BoxFit.contain : BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_introSlideIndex],
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  texts[_introSlideIndex],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 16),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PROLOG VÝPRAVY',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  TextButton(
                    onPressed: _closeIntro,
                    child: const Text('Přeskočit', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildIntroSlide(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_introSlideIndex > 0)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade900,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        setState(() {
                          _introSlideIndex--;
                        });
                      },
                      child: const Text('Zpět'),
                    )
                  else
                    const SizedBox.shrink(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                    child: Text(_introSlideIndex == 2 ? 'Zahájit výpravu' : 'Pokračovat'),
                  ),
                ],
              ),
            ],
          ),
        ),
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

    // Interpolate
    double segmentTotal = (nodeB.requiredDistance - nodeA.requiredDistance).toDouble();
    double segmentProgress = (walkedMeters - nodeA.requiredDistance) / (segmentTotal > 0 ? segmentTotal : 1.0);

    double x = nodeA.mapPosition.dx + (nodeB.mapPosition.dx - nodeA.mapPosition.dx) * segmentProgress;
    double y = nodeA.mapPosition.dy + (nodeB.mapPosition.dy - nodeA.mapPosition.dy) * segmentProgress;

    return Offset(x, y);
  }

  void _onNodeTap(QuestNode node, QuestState state) {
    final isUnlocked = state.unlockedNodes.contains(node.id);
    if (!isUnlocked) {
      final needed = node.requiredDistance - state.currentDistanceWalked;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('🔒 Lokace uzamčena', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            'Tato část stezky je zahalená hustou mlhou. Abys sem mohl vstoupit, musíš ujít ještě ${needed.toInt()} metrů.',
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
      return;
    }

    // Navigate to location screen
    if (node.id == 'node1' || node.id == 'node2' || node.id == 'node3') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id),
        ),
      );
    } else if (node.id == 'node4') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id), // Point and click for swamp exterior/interior
        ),
      );
    } else if (node.id == 'node5') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id), // Point and click for castle courtyard
        ),
      );
    } else if (node.id == 'node6') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PointAndClickScreen(nodeId: node.id), // Altar
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PŘÍBĚHOVÁ VÝPRAVA'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Zobrazit prolog příběhu',
            onPressed: () {
              setState(() {
                _showIntro = true;
                _introSlideIndex = 0;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Restartovat příběh',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Restartovat výpravu?'),
                  content: const Text('Tímto přmažeš veškerý svůj dosavadní pokrok, předměty a budeš muset začít od nuly. Přejete si pokračovat?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Zrušit'),
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
            },
          ),
        ],
      ),
      body: _showIntro
          ? _buildIntroWidget()
          : ValueListenableBuilder<QuestState>(
              valueListenable: _service.stateNotifier,
              builder: (context, state, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final mapWidth = constraints.maxWidth;
              final mapHeight = constraints.maxHeight;

              final avatarPos = _getAvatarPosition(state.currentDistanceWalked);

              return Stack(
                children: [
                  // Map Background Image
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/story_map.png',
                      fit: BoxFit.cover,
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
                      ),
                    ),
                  ),

                  // Render nodes (Locations)
                  ..._service.nodes.map((node) {
                    final isUnlocked = state.unlockedNodes.contains(node.id);
                    final isCompleted = state.completedNodes.contains(node.id);
                    final posX = node.mapPosition.dx * mapWidth;
                    final posY = node.mapPosition.dy * mapHeight;

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
                    left: (avatarPos.dx * mapWidth) - 20,
                    top: (avatarPos.dy * mapHeight) - 35,
                    child: IgnorePointer(
                      child: _buildAvatarMarker(),
                    ),
                  ),

                  // Progress Header HUD Card
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.white.withOpacity(0.92),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            const Icon(Icons.directions_walk, color: Colors.lightBlue, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pokrok ve výpravě',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Uchozeno: ${(state.currentDistanceWalked / 1000).toStringAsFixed(2)} km / 6.00 km',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.lime.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '🎒 ${state.inventory.length} věcí',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.lime.shade900),
                              ),
                            )
                          ],
                        ),
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

  _MapPathPainter({
    required this.nodes,
    required this.walkedDistance,
    required this.unlockedNodes,
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

    // Draw segment lines
    for (int i = 0; i < nodes.length - 1; i++) {
      final nodeA = nodes[i];
      final nodeB = nodes[i + 1];

      final posA = Offset(nodeA.mapPosition.dx * size.width, nodeA.mapPosition.dy * size.height);
      final posB = Offset(nodeB.mapPosition.dx * size.width, nodeB.mapPosition.dy * size.height);

      final isSegmentCompleted = unlockedNodes.contains(nodeB.id);

      if (isSegmentCompleted) {
        canvas.drawLine(posA, posB, paintCompleted);
      } else {
        // Draw dashed line for locked segments
        _drawDashedLine(canvas, posA, posB, paintLocked);
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
        oldDelegate.unlockedNodes.length != unlockedNodes.length;
  }
}
