import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';


class LogicPuzzlesScreen extends StatefulWidget {
  final String puzzleType; // 'combination_lock', 'scales', 'bookshelf', 'telescope'
  final String? correctCode;
  final VoidCallback onSolved;

  const LogicPuzzlesScreen({
    super.key,
    required this.puzzleType,
    this.correctCode,
    required this.onSolved,
  });

  @override
  State<LogicPuzzlesScreen> createState() => _LogicPuzzlesScreenState();
}

class _LogicPuzzlesScreenState extends State<LogicPuzzlesScreen> {
  // Combination lock state
  final List<int> _dialValues = [0, 0, 0];

  // Winch Scales state
  final List<String> _selectedWinchItems = [];
  String _winchFeedbackText = 'Kliknutím nalož předměty na plošinu. Kbelík studny váží 20 kg. Lano unese 21 až 28 kg.';
  String _winchState = 'idle'; // 'idle', 'lifting', 'snapped', 'too_light'
  bool _leverPulled = false;
  Timer? _winchTimer;
  int _iceWeight = 5;
  int _squirrelWeight = 2;
  int _iceMeltingCounter = 0;
  final FlutterTts _tts = FlutterTts();
  double _shakeOffset = 0.0;
  double _winchDisplayWeight = 0.0;

  // Concentric Rune image state
  ui.Image? _runeBoardImage;

  @override
  void initState() {
    super.initState();
    _startWinchTimer();
    _initTts();
    if (widget.puzzleType == 'rune_ritual') {
      _loadRuneBoardImage();
    }
  }

  Future<void> _loadRuneBoardImage() async {
    try {
      final data = await rootBundle.load('assets/images/story_rune_board_bg.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _runeBoardImage = frameInfo.image;
        });
      }
    } catch (e) {
      debugPrint("Failed to load rune board image: $e");
    }
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

  void _triggerScreenShake() {
    int count = 0;
    Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || count > 12) {
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

  @override
  void dispose() {
    _winchTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _startWinchTimer() {
    _winchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        // 1. Ice melting logic (decreases weight by 1 kg every 5 seconds, down to 1 kg)
        _iceMeltingCounter++;
        if (_iceMeltingCounter >= 5) {
          _iceMeltingCounter = 0;
          if (_iceWeight > 1) {
            _iceWeight--;
            if (_selectedWinchItems.contains('ice')) {
              _winchFeedbackText = 'Led před očima taje! Jeho váha klesla na $_iceWeight kg!';
            }
          }
        }

        // 2. Squirrel jumping logic (swaps weight between 2 and 6 kg every 3 seconds)
        if (DateTime.now().second % 3 == 0) {
          final oldWeight = _squirrelWeight;
          _squirrelWeight = _squirrelWeight == 2 ? 6 : 2;
          if (oldWeight != _squirrelWeight && _selectedWinchItems.contains('squirrel')) {
            _winchFeedbackText = 'Veverka poskočila! Její váha na váze kolísá a teď váží $_squirrelWeight kg!';
          }
        }
      });
    });
  }

  final List<Map<String, dynamic>> _winchItems = [
    {
      'id': 'boulder',
      'emoji': '🪨',
      'name': 'Velký lesní balvan',
      'description': 'Obří kus šedé skály.',
      'weight': 1,
      'response': 'Zajímavá volba... ale počkat! Tenhle balvan je vyřezaný z lehkého polystyrenu a váží jen 1 kg!',
    },
    {
      'id': 'lead',
      'emoji': '🔘',
      'name': 'Olověné těžítko',
      'description': 'Malá kovová kulička.',
      'weight': 12,
      'response': 'Páni, to je poctivé olovo! Na svou velikost váží neuvěřitelných 12 kg.',
    },
    {
      'id': 'balloon',
      'emoji': '🎈',
      'name': 'Helium balónek',
      'description': 'Zářivě červený balónek.',
      'weight': -2,
      'response': 'Balónek naplněný heliem! Lehčí než vzduch, takže váhu nadlehčuje o -2 kg!',
    },
    {
      'id': 'ice',
      'emoji': '❄️',
      'name': 'Kus tajícího ledu',
      'description': 'Velká ledová kra.',
      'weight': 5, // This is dynamic
      'response': 'Led z bažiny, který ale v teplém vzduchu studny rychle taje! Váží 5 kg a každých 5 vteřin o 1 kg roztaje.',
    },
    {
      'id': 'squirrel',
      'emoji': '🐿️',
      'name': 'Jankovitá veverka',
      'description': 'Veverka, co ráda skáče.',
      'weight': 2, // This is dynamic
      'response': 'Veverka neposedně pobíhá. Každou chvíli poskočí a její váha kolísá mezi 2 kg a 6 kg!',
    },
    {
      'id': 'magnet',
      'emoji': '🧲',
      'name': 'Magnetická podkova',
      'description': 'Stará zrezivělá podkova.',
      'weight': 10,
      'response': 'Magnetická podkova! Přichytila se na železnou konstrukci studny a magnetismus ji táhne dolů jako 10 kg!',
    },
    {
      'id': 'paper_anvil',
      'emoji': '🧱',
      'name': 'Origami kovadlina',
      'description': 'Vypadá jako 50 kg železa.',
      'weight': 0,
      'response': 'Dokonalé papírové origami ve tvaru kovadliny! Vypadá těžce, ale váží přesně 0 kg!',
    },
    {
      'id': 'mercury',
      'emoji': '🧪',
      'name': 'Láhev se rtutí',
      'description': 'Malá lahvička se stříbrem.',
      'weight': 14,
      'response': 'Ta stříbrná tekutina uvnitř není voda, ale rtuť! Extrémně těžký tekutý kov o váze 14 kg.',
    },
    {
      'id': 'feather_bag',
      'emoji': '🪶',
      'name': 'Pytel peří',
      'description': 'Velký nadýchaný pytel.',
      'weight': 9,
      'response': 'Čekal jsi lehké peří, ale někdo na dno pytle ukryl těžký ocelový klíč! Pytel tak váží nečekaných 9 kg.',
    },
    {
      'id': 'gold_box',
      'emoji': '🎁',
      'name': 'Krabice od zlata',
      'description': 'Krabice s nápisem ZLATO.',
      'weight': 0,
      'response': 'Krabice s nápisem ZLATO je úplně prázdná! Někdo tě napálil, váží 0 kg.',
    },
    {
      'id': 'petrified_shroom',
      'emoji': '🍄',
      'name': 'Zkamenělá obří houba',
      'description': 'Houba ze zkamenělého dřeva.',
      'weight': 8,
      'response': 'Tahle obří houba už dávno zkameněla, je to kus těžkého křemene o váze 8 kg.',
    },
    {
      'id': 'log',
      'emoji': '🪵',
      'name': 'Dubové poleno',
      'description': 'Kus tvrdého dřeva.',
      'weight': 6,
      'response': 'Pořádný kus tvrdého dubového dřeva o váze 6 kg.',
    },
    {
      'id': 'chalice',
      'emoji': '🏆',
      'name': 'Rituální pohár',
      'description': 'Zlatý kalich z chrámu.',
      'weight': 8,
      'response': 'Tento masivní pohár ze zlata váží pěkných 8 kg.',
    },
    {
      'id': 'spellbook',
      'emoji': '📜',
      'name': 'Kniha kouzel',
      'description': 'Tlustá kniha s kováním.',
      'weight': 4,
      'response': 'Tlustá kniha s těžkým kováním vážící 4 kg.',
    },
    {
      'id': 'pan',
      'emoji': '🍳',
      'name': 'Litinová pánev',
      'description': 'Těžká pánev z chýše.',
      'weight': 3,
      'response': 'Litinová pánev, která váží solidní 3 kg.',
    },
    {
      'id': 'pumpkin',
      'emoji': '🎃',
      'name': 'Velká dýně',
      'description': 'Dýně ze zahrádky.',
      'weight': 7,
      'response': 'Zralá oranžová dýně ze záhonu o váze 7 kg.',
    },
    {
      'id': 'statue',
      'emoji': '🗿',
      'name': 'Bronzová soška',
      'description': 'Soška lesního bůžka.',
      'weight': 9,
      'response': 'Bronzová soška bůžka o váze 9 kg.',
    },
    {
      'id': 'boot',
      'emoji': '🥾',
      'name': 'Stará bota',
      'description': 'Zablácená bota.',
      'weight': 2,
      'response': 'Kožená bota plná suchého bahna. Váží 2 kg.',
    },
    {
      'id': 'bread',
      'emoji': '🍞',
      'name': 'Ztvrdlý chléb',
      'description': 'Bochník starého chleba.',
      'weight': 2,
      'response': 'Starý chléb, který je ztvrdlý na kámen. Váží 2 kg.',
    },
    {
      'id': 'jug',
      'emoji': '🏺',
      'name': 'Hliněný džbán',
      'description': 'Keramická nádoba.',
      'weight': 4,
      'response': 'Prázdný keramický džbán o váze 4 kg.',
    },
  ];

  // Bookshelf state
  final List<String> _books = ['Cyril', 'Ambrož', 'David', 'Bohumil'];
  final List<String> _correctBooksOrder = ['Ambrož', 'Bohumil', 'Cyril', 'David'];

  // Telescope state
  int _telescopeStep = 0; // 0 = Medved, 1 = Vlk, 2 = Jelen
  Offset _skyOffset = const Offset(-480, -280);
  String? _astronomerSpeech;
  Timer? _speechBubbleTimer;

  // Concentric Rune state
  double _outerAngle = 90.0;
  double _middleAngle = 180.0;
  double _innerAngle = 270.0;

  bool _isSolved = false;

  void _checkSolution() {
    if (_isSolved) return;

    bool solved = false;

    if (widget.puzzleType == 'combination_lock') {
      final code = _dialValues.join();
      solved = (code == widget.correctCode);
      if (solved) {
        _speak('Zámek s těžkým kovovým cvaknutím povolil. Truhla je otevřená!');
      }
    } else if (widget.puzzleType == 'scales') {
      solved = (_winchState == 'lifting');
    } else if (widget.puzzleType == 'bookshelf') {
      solved = true;
      for (int i = 0; i < _books.length; i++) {
        if (_books[i] != _correctBooksOrder[i]) {
          solved = false;
          break;
        }
      }
      if (solved) {
        _speak('Něco tiše cvaklo a regál s knihami se s rachotem odsunul!');
      }
    } else if (widget.puzzleType == 'telescope') {
      solved = _isSolved;
    } else if (widget.puzzleType == 'rune_ritual') {
      solved = _isSolved;
    }

    if (solved) {
      setState(() {
        _isSolved = true;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          widget.onSolved();
          Navigator.pop(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Logická Hádanka";
    Widget puzzleWidget = const SizedBox.shrink();

    if (widget.puzzleType == 'combination_lock') {
      title = "🔐 Runový číselný zámek";
      puzzleWidget = _buildCombinationLock();
    } else if (widget.puzzleType == 'scales') {
      title = "⚙️ Naviják staré studny";
      puzzleWidget = _buildScales();
    } else if (widget.puzzleType == 'bookshelf') {
      title = "📚 Knihovní šifra";
      puzzleWidget = _buildBookshelf();
    } else if (widget.puzzleType == 'telescope') {
      title = "🔭 Hvězdný dalekohled";
      puzzleWidget = _buildTelescope();
    } else if (widget.puzzleType == 'rune_ritual') {
      title = "🔮 Runový Rituál";
      puzzleWidget = _buildRuneRitual();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Card(
                    color: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 8,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: _isSolved
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.check_circle, color: Colors.green, size: 80),
                                SizedBox(height: 16),
                                Text(
                                  'VYŘEŠENO!',
                                  style: TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : puzzleWidget,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Přemýšlej a kombinuj indicie, které jsi získal z příběhu a zkoumání okolí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Combination Lock Widget
  Widget _buildCombinationLock() {
    final runes = ['ᛟ', 'ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ', 'ᚺ'];
    final isCodeCorrect = _dialValues.join() == widget.correctCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🔐 Starodávný runový zámek',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Nastav správnou trojmístnou runovou kombinaci:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 32),

        // Padlock Interactive Area
        SizedBox(
          width: 300,
          height: 280,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 1. Padlock Shackle/Arch (Metallic curve)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                top: isCodeCorrect ? -45 : -10,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutBack,
                  turns: isCodeCorrect ? -0.06 : 0.0,
                  alignment: Alignment.bottomLeft,
                  child: SizedBox(
                    width: 140,
                    height: 100,
                    child: CustomPaint(
                      painter: _PadlockShacklePainter(),
                    ),
                  ),
                ),
              ),

              // 2. Padlock Body (Stone / Brass Plate)
              Positioned(
                top: 60,
                child: Container(
                  width: 280,
                  height: 190,
                  decoration: BoxDecoration(
                    gradient: const RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [Colors.grey, Color(0xFF0F0F0F)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isCodeCorrect ? Colors.amber.shade400 : Colors.amber.shade700,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                      if (isCodeCorrect)
                        BoxShadow(
                          color: Colors.amber.shade400.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Carved details/rivets
                      Positioned(
                        left: 12, top: 12,
                        child: Icon(Icons.circle, size: 8, color: Colors.amber.shade900),
                      ),
                      Positioned(
                        right: 12, top: 12,
                        child: Icon(Icons.circle, size: 8, color: Colors.amber.shade900),
                      ),
                      Positioned(
                        left: 12, bottom: 12,
                        child: Icon(Icons.circle, size: 8, color: Colors.amber.shade900),
                      ),
                      Positioned(
                        right: 12, bottom: 12,
                        child: Icon(Icons.circle, size: 8, color: Colors.amber.shade900),
                      ),

                      // Runic Dial Rows
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(3, (index) {
                            final value = _dialValues[index];
                            final rune = runes[value];

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Arrow UP button
                                _buildDialArrowButton(
                                  icon: Icons.keyboard_arrow_up,
                                  onPressed: isCodeCorrect
                                      ? null
                                      : () {
                                          _speak('cvak');
                                          setState(() {
                                            _dialValues[index] = (_dialValues[index] + 1) % 10;
                                          });
                                          _checkSolution();
                                        },
                                ),

                                // The Dial (Circular Brass Ring)
                                Container(
                                  width: 65,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.amber, Color(0xFF2A1B0A)],
                                    ),
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isCodeCorrect
                                          ? Colors.cyanAccent
                                          : Colors.amber.shade600,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Rune symbol
                                      Text(
                                        rune,
                                        style: TextStyle(
                                          color: isCodeCorrect
                                              ? Colors.cyanAccent
                                              : Colors.cyan.shade300,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          shadows: [
                                            Shadow(
                                              color: isCodeCorrect
                                                  ? Colors.cyanAccent.withOpacity(0.8)
                                                  : Colors.cyan.withOpacity(0.5),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      // Digit
                                      Text(
                                        value.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Arrow DOWN button
                                _buildDialArrowButton(
                                  icon: Icons.keyboard_arrow_down,
                                  onPressed: isCodeCorrect
                                      ? null
                                      : () {
                                          _speak('cvak');
                                          setState(() {
                                            _dialValues[index] = (_dialValues[index] - 1 + 10) % 10;
                                          });
                                          _checkSolution();
                                        },
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDialArrowButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      width: 44,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: Colors.amber.shade600, size: 28),
        onPressed: onPressed,
      ),
    );
  }
              Widget _buildScales() {
    int totalWeight = 0;
    for (var itemId in _selectedWinchItems) {
      final item = _winchItems.firstWhere((it) => it['id'] == itemId);
      if (itemId == 'ice') {
        totalWeight += _iceWeight;
      } else if (itemId == 'squirrel') {
        totalWeight += _squirrelWeight;
      } else {
        totalWeight += item['weight'] as int;
      }
    }

    // Determine positions of bucket and platform based on state
    double bucketY = 130.0; // Idle position (bottom of well)
    double platformY = 40.0; // Idle position (top of scale)
    double winchTurns = 0.0; // Winch rotation in turns
    double platformTilt = 0.0; // Winch platform tilt angle
    double brokenOpacity = 0.0; // Snap text opacity
    
    if (_winchState == 'too_light') {
      bucketY = 130.0;
      platformY = 45.0; // tiny dip
      winchTurns = 0.05;
    } else if (_winchState == 'lifting') {
      bucketY = 30.0; // Raised to the top
      platformY = 130.0; // Dropped to the bottom
      winchTurns = 3.0; // Spun 3 times
    } else if (_winchState == 'snapped') {
      bucketY = 150.0; // Plunged down
      platformY = 170.0; // Dropped and fell
      winchTurns = 1.5;
      platformTilt = 0.4; // Tilted (broken)
      brokenOpacity = 1.0;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Title / Instruction
        Text(
          'Vyvaž naviják studny. Kbelík váží 20 kg. Musíš označit předměty o váze 21 až 28 kg, aby vyjel nahoru. Pozor, lano unese nejvýše 28 kg!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),

        // 2. The Interactive Altar & Well (Winch Area with Shake Effect)
        Transform.translate(
          offset: Offset(_shakeOffset, 0),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                center: Alignment.center,
                radius: 1.3,
                colors: [Color(0xFF1B2A24), Color(0xFF0C1210)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _winchState == 'lifting'
                    ? Colors.greenAccent.withOpacity(0.6)
                    : _winchState == 'snapped'
                        ? Colors.redAccent.withOpacity(0.6)
                        : const Color(0xFFC5A059).withOpacity(0.35),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _winchState == 'lifting'
                      ? Colors.green.withOpacity(0.25)
                      : _winchState == 'snapped'
                          ? Colors.red.withOpacity(0.25)
                          : Colors.black80,
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              children: [
                // Background well stone wall column (left side)
                Positioned(
                  left: 10,
                  top: 36,
                  bottom: 10,
                  width: 70,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade800, Colors.grey.shade700, Colors.grey.shade900],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      border: Border.all(color: Colors.white10),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(6, (index) => const Divider(color: Colors.white12, height: 1)),
                    ),
                  ),
                ),

                // Winch Drum (Center support bar & pulley)
                Positioned(
                  left: 45,
                  right: 90,
                  top: 36,
                  height: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade900, Colors.grey.shade600, Colors.grey.shade950],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Animated Winch Wheel (Pulleys)
                Positioned(
                  left: 40,
                  top: 22,
                  width: 40,
                  height: 40,
                  child: AnimatedRotation(
                    turns: winchTurns,
                    duration: Duration(milliseconds: _winchState == 'lifting' ? 1200 : 300),
                    child: Icon(Icons.settings, color: Colors.amber.shade800, size: 40),
                  ),
                ),
                Positioned(
                  right: 85,
                  top: 22,
                  width: 40,
                  height: 40,
                  child: AnimatedRotation(
                    turns: winchTurns,
                    duration: Duration(milliseconds: _winchState == 'lifting' ? 1200 : 300),
                    child: Icon(Icons.settings, color: Colors.amber.shade800, size: 40),
                  ),
                ),

                // Winch Dial Gauge Indicator
                Positioned(
                  left: 100,
                  right: 100,
                  top: 6,
                  height: 55,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: _winchDisplayWeight),
                    duration: const Duration(milliseconds: 1200),
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          CustomPaint(
                            size: const Size(80, 32),
                            painter: _WinchDialPainter(currentWeight: value),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ZATÍŽENÍ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Winch Lever (Pull Lever)
                Positioned(
                  right: 15,
                  top: 15,
                  width: 50,
                  height: 80,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _leverPulled || _winchState == 'lifting'
                            ? null
                            : () {
                                setState(() {
                                  _leverPulled = true;
                                });

                                // Run simulation logic
                                if (totalWeight <= 20) {
                                  setState(() {
                                    _winchState = 'too_light';
                                    _winchFeedbackText = 'Zatahal jsi za páku... Plošina ($totalWeight kg) je moc lehká a kbelík (20 kg) se ani nehnul.';
                                  });
                                  _speak('To je moc lehké. Kbelík se ani nepohnul.');
                                  Future.delayed(const Duration(milliseconds: 1500), () {
                                    if (mounted) {
                                      setState(() {
                                        _winchState = 'idle';
                                        _leverPulled = false;
                                      });
                                    }
                                  });
                                } else if (totalWeight >= 21 && totalWeight <= 28) {
                                  setState(() {
                                    _winchState = 'lifting';
                                    _winchFeedbackText = 'Kolo navijáku se otáčí! Závaží ($totalWeight kg) stahuje plošinu dolů a kbelík stoupá nahoru!';
                                  });
                                  _speak('Mám to! Kbelík stoupá nahoru.');
                                  _checkSolution();
                                } else {
                                  setState(() {
                                    _winchState = 'snapped';
                                    _winchFeedbackText = 'KŘUP! Plošina s váhou $totalWeight kg byla moc těžká! Lano nevydrželo nápor a prasklo!';
                                  });
                                  _triggerScreenShake();
                                  _speak('Křup! Lano nevydrželo a prasklo.');
                                  Future.delayed(const Duration(milliseconds: 3000), () {
                                    if (mounted) {
                                      setState(() {
                                        _selectedWinchItems.clear();
                                        _winchState = 'idle';
                                        _winchFeedbackText = 'Vyber předměty znovu a opatrněji. Lano unese nejvýše 28 kg.';
                                        _leverPulled = false;
                                      });
                                    }
                                  });
                                }
                              },
                        child: Container(
                          width: 24,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E2E2E), // Cast iron base
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF4A4A4A), width: 1.5),
                            boxShadow: const [BoxShadow(color: Colors.black80, blurRadius: 4)],
                          ),
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // Handle stick/rod
                              AnimatedPositioned(
                                duration: const Duration(milliseconds: 250),
                                bottom: _leverPulled ? 4 : 22,
                                left: 5,
                                child: Column(
                                  children: [
                                    // Wooden handle knob
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF8B4513), // Wood brown knob
                                        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 1)],
                                      ),
                                    ),
                                    // Metal rod
                                    Container(
                                      width: 3,
                                      height: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('PÁKA', style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),


                // Ropes from drum
                // Left Rope (connecting Pulley Left to Bucket)
                Positioned(
                  left: 59,
                  top: 42,
                  height: bucketY + 12,
                  width: 2,
                  child: Container(color: Colors.orange.shade800),
                ),

                // Right Rope (connecting Pulley Right to Platform)
                Positioned(
                  right: 104,
                  top: 42,
                  height: platformY + 10,
                  width: 2,
                  child: Container(
                    color: _winchState == 'snapped' ? Colors.transparent : Colors.orange.shade800,
                  ),
                ),

                // Left Item: The Water Bucket (🪣)
                AnimatedPositioned(
                  duration: Duration(milliseconds: _winchState == 'lifting' ? 1200 : _winchState == 'snapped' ? 300 : 400),
                  curve: _winchState == 'snapped' ? Curves.bounceOut : Curves.easeInOut,
                  left: 40,
                  top: bucketY,
                  width: 40,
                  height: 50,
                  child: Column(
                    children: [
                      const Text('🪣', style: TextStyle(fontSize: 26)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Text('KBELÍK', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                // Right Item: The Platform (basket with items)
                AnimatedPositioned(
                  duration: Duration(milliseconds: _winchState == 'lifting' ? 1200 : _winchState == 'snapped' ? 300 : 400),
                  curve: Curves.easeInOut,
                  right: 75,
                  top: platformY,
                  width: 60,
                  height: 70,
                  child: AnimatedRotation(
                    turns: platformTilt,
                    duration: const Duration(milliseconds: 1200),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Triangle suspension ropes
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScaleSuspensionPainter(),
                          ),
                        ),
                        // Plate and items
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Placed items emojis (up to 5 stacked/shown)
                            Container(
                              height: 24,
                              alignment: Alignment.bottomCenter,
                              child: Wrap(
                                spacing: -4,
                                children: _selectedWinchItems.map((itemId) {
                                  final item = _winchItems.firstWhere((it) => it['id'] == itemId);
                                  return Text(item['emoji'] as String, style: const TextStyle(fontSize: 16));
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // The Wooden Basket Plate representation
                            Container(
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5A2B), // Wood brown
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: const Color(0xFF5A3A1C)),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                        // Label container
                        Positioned(
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: const Text(
                              'ZÁVAŽÍ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),


                // Broken Rope Indicator ("KŘUP! 💥")
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: brokenOpacity,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'KŘUP! 💥',
                              style: TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Lano se přetrhlo pod obří vahou!',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Feedback Dialog Bubble from Hero
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF262626),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade700),
          ),
          child: Row(
            children: [
              const Text('🧑', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _winchFeedbackText,
                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Reset & Status bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Naloženo: ${_selectedWinchItems.length}/5 předmětů',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            if (_selectedWinchItems.isNotEmpty && !_leverPulled)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedWinchItems.clear();
                    _winchDisplayWeight = 0.0;
                    _winchFeedbackText = 'Plošina vyčištěna. Vyber předměty znovu.';
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.orange, size: 16),
                label: const Text('Vyčistit plošinu', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // 5. Scrollable Grid of 20 Available items
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.95,
              ),
              itemCount: _winchItems.length,
              itemBuilder: (context, index) {
                final item = _winchItems[index];
                final String itemId = item['id'] as String;
                final bool isSelected = _selectedWinchItems.contains(itemId);

                int displayWeight = item['weight'] as int;
                if (itemId == 'ice') displayWeight = _iceWeight;
                if (itemId == 'squirrel') displayWeight = _squirrelWeight;

                return AnimatedScale(
                  scale: isSelected ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  child: GestureDetector(
                    onTap: _leverPulled || _winchState == 'lifting'
                        ? null
                        : () {
                            setState(() {
                              if (isSelected) {
                                _selectedWinchItems.remove(itemId);
                                _winchFeedbackText = 'Odebráno: ${item['name']}.';
                              } else {
                                if (_selectedWinchItems.length >= 5) {
                                  _winchFeedbackText = 'Můžeš vybrat nejvýše 5 předmětů najednou!';
                                  _speak('Můžeš vybrat nejvýše pět předmětů.');
                                } else {
                                  _selectedWinchItems.add(itemId);
                                  _winchFeedbackText = item['response'] as String;
                                  final speakText = (item['response'] as String)
                                      .replaceAll('!', '')
                                      .replaceAll('...', '.');
                                  _speak(speakText);
                                }
                              }
                            });
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [Colors.amber.shade900, const Color(0xFF2A1B0A)]
                              : [const Color(0xFF232323), Colors.grey.shade900],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.amber.shade500 : Colors.grey.shade700,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(color: Colors.amber.shade900.withOpacity(0.4), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item['emoji'] as String, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(
                            item['name'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade300,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // 3. Bookshelf Widget
  Widget _buildBookshelf() {
    final Map<String, Map<String, dynamic>> bookSpecs = {
      'Ambrož': {
        'color': Colors.red.shade900,
        'height': 155.0,
        'width': 60.0,
        'comment': 'Červená kniha od Ambrože pojednává o tajích lesních bylin.',
        'trim': Colors.amber.shade700,
        'subtitle': 'HERBARIUM',
      },
      'Bohumil': {
        'color': Colors.blue.shade900,
        'height': 140.0,
        'width': 56.0,
        'comment': 'Modrý svazek od Bohumila popisuje mapování noční oblohy.',
        'trim': Colors.yellow.shade500,
        'subtitle': 'ASTRONOMIA',
      },
      'Cyril': {
        'color': Colors.green.shade900,
        'height': 160.0,
        'width': 62.0,
        'comment': 'Zelená kronika od Cyrila vypráví o založení chrámu v bažinách.',
        'trim': Colors.amber.shade600,
        'subtitle': 'HISTORIA',
      },
      'David': {
        'color': Colors.purple.shade900,
        'height': 148.0,
        'width': 58.0,
        'comment': 'Fialová kniha od Davida je plná mystických runových vzorců.',
        'trim': Colors.orangeAccent,
        'subtitle': 'RUNOLOGIA',
      },
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '📚 Starobylá knihovna',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Seřaď svazky knih abecedně od A do Z (podle jmen autorů):',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 28),

        // Mahogany bookcase
        Container(
          width: 320,
          height: 210,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.brown.shade700, Colors.brown.shade900],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1B0F05), width: 6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Backing shelf shadows/lines
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(child: Container(color: Colors.black.withOpacity(0.15))),
                    Container(
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.brown.shade900, Colors.black],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Books Stack
              ...['Ambrož', 'Bohumil', 'Cyril', 'David'].map((bookName) {
                final spec = bookSpecs[bookName]!;
                final int currentIndex = _books.indexOf(bookName);
                final double leftPos = 12.0 + currentIndex * 72.0;

                return AnimatedPositioned(
                  key: ValueKey(bookName),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutBack,
                  left: leftPos,
                  bottom: 16, // Sits on the shelf board
                  width: spec['width'] as double,
                  height: spec['height'] as double,
                  child: GestureDetector(
                    onTap: _isSolved
                        ? null
                        : () {
                            // Tap a book to swap with the next one (wrap around)
                            final nextIndex = (currentIndex + 1) % _books.length;
                            setState(() {
                              final temp = _books[currentIndex];
                              _books[currentIndex] = _books[nextIndex];
                              _books[nextIndex] = temp;
                            });
                            _speak(spec['comment'] as String);
                            _checkSolution();
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            spec['color'] as Color,
                            Colors.black.withOpacity(0.2),
                            spec['color'] as Color,
                          ],
                          stops: const [0.0, 0.4, 1.0],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                          bottomLeft: Radius.circular(2),
                          bottomRight: Radius.circular(2),
                        ),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: spec['trim'] as Color,
                            width: 3,
                          ),
                          vertical: const BorderSide(
                            color: Colors.black38,
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Gold foil spine horizontal lines (3D look)
                          Positioned(
                            top: 15,
                            left: 0, right: 0,
                            child: Container(height: 1.5, color: spec['trim'] as Color),
                          ),
                          Positioned(
                            bottom: 15,
                            left: 0, right: 0,
                            child: Container(height: 1.5, color: spec['trim'] as Color),
                          ),

                          // Book spine title
                          Center(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    bookName.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.amber.shade200,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      shadows: const [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    spec['subtitle'] as String,
                                    style: TextStyle(
                                      color: Colors.amber.shade200.withOpacity(0.6),
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Kliknutím na knihu ji prohodíš s knihou napravo.',
          style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
  // 4. Telescope Viewport Panning Widget
  void _checkTelescopeConstellation() {
    final double skyCenterX = 120.0 - _skyOffset.dx;
    final double skyCenterY = 120.0 - _skyOffset.dy;

    Offset targetCenter;
    String cCzech;
    if (_telescopeStep == 0) {
      targetCenter = const Offset(300, 220);
      cCzech = 'Velkého Medvěda';
    } else if (_telescopeStep == 1) {
      targetCenter = const Offset(850, 280);
      cCzech = 'Vlka';
    } else {
      targetCenter = const Offset(600, 580);
      cCzech = 'Jelena';
    }

    final double dx = skyCenterX - targetCenter.dx;
    final double dy = skyCenterY - targetCenter.dy;
    final double distance = math.sqrt(dx * dx + dy * dy);

    _speechBubbleTimer?.cancel();
    if (distance < 80.0) {
      _speak('Super! Našel jsi souhvězdí ' + cCzech + '.');
      setState(() {
        _astronomerSpeech = 'Super! Našel jsi souhvězdí ' + cCzech + '.';
        if (_telescopeStep < 2) {
          _telescopeStep++;
        } else {
          _astronomerSpeech = 'Výborně! Všechna souhvězdí jsou zaměřena. Dveře observatoře se otevírají!';
          _telescopeStep = 3;
        }
      });

      if (_telescopeStep == 3) {
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (mounted) {
            setState(() {
              _isSolved = true;
            });
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                widget.onSolved();
                Navigator.pop(context);
              }
            });
          }
        });
      } else {
        _speechBubbleTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _astronomerSpeech = null;
            });
          }
        });
      }
    } else {
      _speak('Ne, to není ono.');
      setState(() {
        _astronomerSpeech = 'Ne, to není ono. Podívej se znovu na pergamen a zkus zaměřit jinou část oblohy.';
      });
      _speechBubbleTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _astronomerSpeech = null;
          });
        }
      });
    }
  }

  Widget _buildTelescope() {
    String currentCluePath = 'assets/images/clue_telescope_medved.png';
    String currentName = 'Velký Medvěd';
    if (_telescopeStep == 1) {
      currentCluePath = 'assets/images/clue_telescope_vlk.png';
      currentName = 'Vlk';
    } else if (_telescopeStep >= 2) {
      currentCluePath = 'assets/images/clue_telescope_jelen.png';
      currentName = 'Jelen';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🔭 Hvězdný dalekohled',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _telescopeStep >= 3 
            ? 'Všechna souhvězdí jsou úspěšně zaměřena!'
            : 'Posouváním oblohy v dalekohledu najdi souhvězdí z nápovědy:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _telescopeStep >= 3 ? Colors.greenAccent : Colors.amber.shade700,
                      width: 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      if (_telescopeStep >= 3)
                        BoxShadow(
                          color: Colors.greenAccent.withOpacity(0.35),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        GestureDetector(
                          onPanUpdate: _telescopeStep >= 3
                              ? null
                              : (details) {
                                  setState(() {
                                    _skyOffset += details.delta;
                                    _skyOffset = Offset(
                                      _skyOffset.dx.clamp(-1020.0, 0.0),
                                      _skyOffset.dy.clamp(-620.0, 0.0),
                                    );
                                  });
                                },
                          child: Stack(
                            children: [
                              Positioned(
                                left: _skyOffset.dx,
                                top: _skyOffset.dy,
                                child: Image.asset(
                                  'assets/images/story_telescope_sky.png',
                                  width: 1200,
                                  height: 800,
                                  fit: BoxFit.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IgnorePointer(
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber.shade500.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Container(
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.amber.shade500.withOpacity(0.4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hledáček dalekohledu',
                  style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(width: 20),

            Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade800.withOpacity(0.6), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 2)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      currentCluePath,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _telescopeStep >= 3 ? 'Hotovo!' : 'Cíl: ' + currentName,
                  style: TextStyle(color: Colors.amber.shade600, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/story_npc_astronomer.png',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Astronom',
                      style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _astronomerSpeech ??
                          'Najdi v dalekohledu souhvězdí ' + currentName + ' podle této nápovědy a pak klikni na tlačítko níže.',
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _telescopeStep >= 3 ? Colors.green.shade800 : Colors.amber.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _telescopeStep >= 3 ? null : _checkTelescopeConstellation,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('ZAMĚŘENO (NAJITO)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  // 5. Concentric Rune Ritual Puzzle Widget
  Widget _buildRuneRitual() {
    final bool outerAligned = (_outerAngle.round() % 360) == 0;
    final bool middleAligned = (_middleAngle.round() % 360) == 0;
    final bool innerAligned = (_innerAngle.round() % 360) == 0;
    final bool allAligned = outerAligned && middleAligned && innerAligned;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '🔮 Runový Rituál',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Otáčením kruhů propoj runové linie ze středu k okraji:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),

        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: allAligned ? Colors.cyanAccent : Colors.grey.shade800,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              if (allAligned)
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.35),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _runeBoardImage == null
                      ? Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(color: Colors.cyanAccent),
                        )
                      : CustomPaint(
                          painter: _RuneRitualPainter(
                            backgroundImage: _runeBoardImage!,
                            outerAngle: _outerAngle,
                            middleAngle: _middleAngle,
                            innerAngle: _innerAngle,
                            allAligned: allAligned,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        _buildRingControlRow(
          label: 'Vnější kruh (Outer)',
          onLeft: () => _rotateRing('outer', -30),
          onRight: () => _rotateRing('outer', 30),
          isAligned: outerAligned,
        ),
        const SizedBox(height: 8),
        _buildRingControlRow(
          label: 'Střední kruh (Middle)',
          onLeft: () => _rotateRing('middle', -30),
          onRight: () => _rotateRing('middle', 30),
          isAligned: middleAligned,
        ),
        const SizedBox(height: 8),
        _buildRingControlRow(
          label: 'Vnitřní kruh (Inner)',
          onLeft: () => _rotateRing('inner', -30),
          onRight: () => _rotateRing('inner', 30),
          isAligned: innerAligned,
        ),
      ],
    );
  }


  Widget _buildRingControlRow({
    required String label,
    required VoidCallback onLeft,
    required VoidCallback onRight,
    required bool isAligned,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              color: isAligned ? Colors.cyanAccent : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.rotate_left, color: Colors.amber),
          onPressed: _isSolved ? null : onLeft,
        ),
        IconButton(
          icon: const Icon(Icons.rotate_right, color: Colors.amber),
          onPressed: _isSolved ? null : onRight,
        ),
      ],
    );
  }

  void _rotateRing(String ring, double amount) {
    setState(() {
      if (ring == 'outer') {
        _outerAngle += amount;
        _middleAngle -= amount;
      } else if (ring == 'middle') {
        _middleAngle += amount;
        _innerAngle += amount * 2;
      } else if (ring == 'inner') {
        _innerAngle += amount;
      }

      final bool outerAligned = (_outerAngle.round() % 360) == 0;
      final bool middleAligned = (_middleAngle.round() % 360) == 0;
      final bool innerAligned = (_innerAngle.round() % 360) == 0;

      if (outerAligned && middleAligned && innerAligned) {
        _isSolved = true;
        _speak('Magické runy se spojily a amulet se plně nabil!');
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            widget.onSolved();
            Navigator.pop(context);
          }
        });
      }
    });
  }
}

class _RuneRitualPainter extends CustomPainter {
  final ui.Image backgroundImage;
  final double outerAngle;
  final double middleAngle;
  final double innerAngle;
  final bool allAligned;

  _RuneRitualPainter({
    required this.backgroundImage,
    required this.outerAngle,
    required this.middleAngle,
    required this.innerAngle,
    required this.allAligned,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    // We partition the image into 3 concentric zones:
    final double innerR = radius * 0.35; // 35 if radius is 100
    final double middleR = radius * 0.70; // 70 if radius is 100
    final double outerR = radius;       // 100 if radius is 100

    final srcRect = Rect.fromLTWH(0, 0, backgroundImage.width.toDouble(), backgroundImage.height.toDouble());
    final dstRect = Rect.fromCircle(center: center, radius: radius);

    final basePaint = Paint()..isAntiAlias = true;
    if (!allAligned) {
      basePaint.colorFilter = const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);
    }

    // 1. Draw Inner Zone (rotated by innerAngle)
    canvas.save();
    final innerPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerR));
    canvas.clipPath(innerPath);
    
    canvas.translate(center.dx, center.dy);
    canvas.rotate(innerAngle * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    
    canvas.drawImageRect(backgroundImage, srcRect, dstRect, basePaint);
    canvas.restore();

    // 2. Draw Middle Zone (rotated by middleAngle)
    canvas.save();
    final middlePath = Path()..addOval(Rect.fromCircle(center: center, radius: middleR));
    final innerPathForDiff = Path()..addOval(Rect.fromCircle(center: center, radius: innerR));
    final middleClipPath = Path.combine(PathOperation.difference, middlePath, innerPathForDiff);
    canvas.clipPath(middleClipPath);
    
    canvas.translate(center.dx, center.dy);
    canvas.rotate(middleAngle * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    
    canvas.drawImageRect(backgroundImage, srcRect, dstRect, basePaint);
    canvas.restore();

    // 3. Draw Outer Zone (rotated by outerAngle)
    canvas.save();
    final outerPath = Path()..addOval(Rect.fromCircle(center: center, radius: outerR));
    final middlePathForDiff = Path()..addOval(Rect.fromCircle(center: center, radius: middleR));
    final outerClipPath = Path.combine(PathOperation.difference, outerPath, middlePathForDiff);
    canvas.clipPath(outerClipPath);
    
    canvas.translate(center.dx, center.dy);
    canvas.rotate(outerAngle * math.pi / 180);
    canvas.translate(-center.dx, -center.dy);
    
    canvas.drawImageRect(backgroundImage, srcRect, dstRect, basePaint);
    canvas.restore();

    // 4. Draw concentric borders (ring separators) to highlight the concentric circles
    final borderPaint = Paint()
      ..color = allAligned ? Colors.cyanAccent.withOpacity(0.6) : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, innerR, borderPaint);
    canvas.drawCircle(center, middleR, borderPaint);

    // 5. Draw element lines/spokes (overlayed glow and lines to help alignment)
    final List<Map<String, dynamic>> elements = [
      {'angle': 0.0, 'color': Colors.greenAccent, 'emoji': '🌱'},   // Země
      {'angle': 90.0, 'color': Colors.orangeAccent, 'emoji': '🔥'},  // Oheň
      {'angle': 180.0, 'color': Colors.cyanAccent, 'emoji': '💦'},  // Voda
      {'angle': 270.0, 'color': Colors.white, 'emoji': '💨'},       // Vítr
    ];

    void drawSpokeSegment(double rotationAngle, double baseAngle, double iR, double oR, Color color) {
      final double totalAngleRad = (rotationAngle + baseAngle) * math.pi / 180;
      final p1 = Offset(center.dx + iR * math.cos(totalAngleRad), center.dy + iR * math.sin(totalAngleRad));
      final p2 = Offset(center.dx + oR * math.cos(totalAngleRad), center.dy + oR * math.sin(totalAngleRad));

      final Color drawColor = allAligned ? color : Colors.white38;

      final paint = Paint()
        ..color = drawColor.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      if (allAligned) {
        final glow = Paint()
          ..color = color.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, glow);
      }
      canvas.drawLine(p1, p2, paint);
    }


    for (var elem in elements) {
      final double baseAngle = elem['angle'] as double;
      final Color color = elem['color'] as Color;

      drawSpokeSegment(innerAngle, baseAngle, 0, innerR, color);
      drawSpokeSegment(middleAngle, baseAngle, innerR, middleR, color);
      drawSpokeSegment(outerAngle, baseAngle, middleR, outerR - 8, color);
    }

    // 6. Draw static element emojis at the perimeter
    for (var elem in elements) {
      final double angleRad = (elem['angle'] as double) * math.pi / 180;
      final textPos = Offset(
        center.dx + (outerR - 10) * math.cos(angleRad) - 8,
        center.dy + (outerR - 10) * math.sin(angleRad) - 8,
      );
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: elem['emoji'] as String,
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, textPos);
    }
  }

  @override
  bool shouldRepaint(covariant _RuneRitualPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.outerAngle != outerAngle ||
        oldDelegate.middleAngle != middleAngle ||
        oldDelegate.innerAngle != innerAngle ||
        oldDelegate.allAligned != allAligned;
  }
}

class _PadlockShacklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double w = size.width;
    final double h = size.height;

    // Semicircular shackle arch
    path.moveTo(15, h);
    path.lineTo(15, h * 0.5);
    path.arcTo(
      Rect.fromLTWH(15, 15, w - 30, h),
      -math.pi,
      math.pi,
      false,
    );
    path.lineTo(w - 15, h);

    canvas.drawPath(path, paint);

    // Gold core line highlights
    paint.color = Colors.amber.shade700;
    paint.strokeWidth = 4;
    
    final accentPath = Path();
    accentPath.moveTo(25, h);
    accentPath.lineTo(25, h * 0.5);
    accentPath.arcTo(
      Rect.fromLTWH(25, 25, w - 50, h - 20),
      -math.pi,
      math.pi,
      false,
    );
    accentPath.lineTo(w - 25, h);
    canvas.drawPath(accentPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WinchDialPainter extends CustomPainter {
  final double currentWeight;

  _WinchDialPainter({required this.currentWeight});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.height - 6;

    // 1. Draw outer brass rim
    final brassPaint = Paint()
      ..color = const Color(0xFFC5A059) // Antique Brass
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi,
      math.pi,
      false,
      brassPaint,
    );

    // 2. Draw gauge face backing
    final facePaint = Paint()
      ..color = const Color(0xFF1C1E1B)
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi,
      math.pi,
      true,
      facePaint,
    );

    // 3. Draw colored segments on the arc
    final segmentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Underweight segment (0 - 20)
    segmentPaint.color = Colors.orangeAccent.withOpacity(0.5);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi,
      math.pi * (20 / 40),
      false,
      segmentPaint,
    );

    // Safe Target segment (21 - 28)
    segmentPaint.color = Colors.greenAccent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi + math.pi * (20.5 / 40),
      math.pi * (7.5 / 40),
      false,
      segmentPaint,
    );

    // Overweight segment (29 - 40)
    segmentPaint.color = Colors.redAccent.withOpacity(0.7);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      -math.pi + math.pi * (28.5 / 40),
      math.pi * (11.5 / 40),
      false,
      segmentPaint,
    );

    // 4. Draw tick marks on the dial
    final tickPaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    for (int i = 0; i <= 8; i++) {
      final double angle = -math.pi + (math.pi * (i / 8));
      final innerTick = Offset(
        center.dx + (radius - 12) * math.cos(angle),
        center.dy + (radius - 12) * math.sin(angle),
      );
      final outerTick = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      canvas.drawLine(innerTick, outerTick, tickPaint);
    }

    // 5. Draw the Needle with glowing tip
    final double clampWeight = currentWeight.clamp(0.0, 40.0);
    final double needleAngle = -math.pi + (math.pi * (clampWeight / 40.0));
    
    final needleGlow = Paint()
      ..color = Colors.orange.withOpacity(0.3)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    final needlePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + (radius - 6) * math.cos(needleAngle),
      center.dy + (radius - 6) * math.sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needleGlow);
    canvas.drawLine(center, needleEnd, needlePaint);

    // 6. Draw center cap
    final capPaint = Paint()..color = const Color(0xFFC5A059);
    canvas.drawCircle(center, 5, capPaint);
    capPaint.color = Colors.black;
    canvas.drawCircle(center, 2, capPaint);
  }

  @override
  bool shouldRepaint(covariant _WinchDialPainter oldDelegate) {
    return oldDelegate.currentWeight != currentWeight;
  }
}

class _ScaleSuspensionPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(0, size.height - 14), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width, size.height - 14), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


