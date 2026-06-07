import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _startWinchTimer();
    _initTts();
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
  double _angleMedved = 0;
  double _angleVlk = 0;
  double _angleJelen = 0;
  bool _medvedSolvedSpoken = false;
  bool _vlkSolvedSpoken = false;
  bool _jelenSolvedSpoken = false;

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
      // Check individual alignments for spoken cues
      if (_angleMedved == 45 && !_medvedSolvedSpoken) {
        _medvedSolvedSpoken = true;
        _speak('Hvězdy Medvěda se spojily a jasně zazářily!');
      }
      if (_angleVlk == 120 && !_vlkSolvedSpoken) {
        _vlkSolvedSpoken = true;
        _speak('Hvězdy Vlka se spojily a jasně zazářily!');
      }
      if (_angleJelen == 275 && !_jelenSolvedSpoken) {
        _jelenSolvedSpoken = true;
        _speak('Hvězdy Jelena se spojily a jasně zazářily!');
      }

      solved = (_angleMedved == 45 && _angleVlk == 120 && _angleJelen == 275);
      if (solved) {
        _speak('Teleskop je dokonale zaměřen! Hvězdy se propojily a chrámové dveře se otevírají.');
      }
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
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [Colors.grey.shade900, Colors.black],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _winchState == 'lifting'
                    ? Colors.green.withOpacity(0.5)
                    : _winchState == 'snapped'
                        ? Colors.red.withOpacity(0.5)
                        : Colors.amber.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _winchState == 'lifting'
                      ? Colors.green.withOpacity(0.15)
                      : _winchState == 'snapped'
                          ? Colors.red.withOpacity(0.15)
                          : Colors.black54,
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Stack(
              children: [
                // Background well brick pattern representation
                Positioned(
                  left: 10,
                  top: 40,
                  bottom: 10,
                  width: 70,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24, width: 1),
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
                        colors: [Colors.grey.shade800, Colors.grey.shade600, Colors.grey.shade900],
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
                    child: Icon(Icons.incomplete_circle_rounded, color: Colors.amber.shade800, size: 40),
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
                    child: Icon(Icons.incomplete_circle_rounded, color: Colors.amber.shade800, size: 40),
                  ),
                ),

                // Winch Dial Gauge Indicator
                Positioned(
                  left: 100,
                  right: 100,
                  top: 6,
                  height: 55,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: totalWeight.toDouble()),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Column(
                        children: [
                          CustomPaint(
                            size: const Size(80, 32),
                            painter: _WinchDialPainter(currentWeight: value),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${value.toInt()} kg',
                            style: TextStyle(
                              color: totalWeight > 28
                                  ? Colors.redAccent
                                  : totalWeight > 20
                                      ? Colors.greenAccent
                                      : Colors.amberAccent,
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
                  right: 10,
                  top: 15,
                  width: 60,
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
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _leverPulled ? Colors.red.shade900 : Colors.amber.shade900,
                            border: Border.all(color: Colors.amber.shade300, width: 1.5),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 2))],
                          ),
                          alignment: Alignment.center,
                          child: AnimatedRotation(
                            turns: _leverPulled ? 0.12 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(Icons.build_outlined, color: Colors.white, size: 24),
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
                        child: const Text('20 kg', style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold)),
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
                    duration: const Duration(milliseconds: 300),
                    child: Column(
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
                        // The Basket Plate representation
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade800,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: Colors.amber.shade900),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '$totalWeight kg',
                            style: TextStyle(
                              color: totalWeight > 28 ? Colors.redAccent : Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
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
                          Text(
                            '$displayWeight kg',
                            style: TextStyle(
                              color: isSelected ? Colors.amberAccent : Colors.grey.shade500,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
  }                        '$displayWeight kg',
                          style: TextStyle(
                            color: isSelected ? Colors.amberAccent : Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

  // 4. Telescope Widget
  Widget _buildTelescope() {
    final isMedvedAligned = _angleMedved == 45;
    final isVlkAligned = _angleVlk == 120;
    final isJelenAligned = _angleJelen == 275;
    final allAligned = isMedvedAligned && isVlkAligned && isJelenAligned;

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
          'Otáčením mosazných astro-ciferníků zaměř souhvězdí v průzoru:',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 18),

        // Live circular starry viewport
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
            ),
            border: Border.all(
              color: allAligned ? Colors.cyanAccent : Colors.amber.shade700,
              width: 5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
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
            child: CustomPaint(
              painter: _TelescopeStarfieldPainter(
                angleMedved: _angleMedved,
                angleVlk: _angleVlk,
                angleJelen: _angleJelen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Astro-Dials Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AstroDial(
                label: '🐻 Medvěd',
                value: _angleMedved,
                target: 45,
                onChanged: (val) {
                  setState(() {
                    _angleMedved = val;
                  });
                  _checkSolution();
                },
              ),
            ),
            Expanded(
              child: _AstroDial(
                label: '🐺 Vlk',
                value: _angleVlk,
                target: 120,
                onChanged: (val) {
                  setState(() {
                    _angleVlk = val;
                  });
                  _checkSolution();
                },
              ),
            ),
            Expanded(
              child: _AstroDial(
                label: '🦌 Jelen',
                value: _angleJelen,
                target: 275,
                onChanged: (val) {
                  setState(() {
                    _angleJelen = val;
                  });
                  _checkSolution();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WinchDialPainter extends CustomPainter {
  final double currentWeight;

  _WinchDialPainter({required this.currentWeight});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 4);
    final radius = size.height - 8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    // Draw background arcs
    paint.color = Colors.grey.shade700;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159,
      3.14159 * (20 / 40),
      false,
      paint,
    );

    paint.color = Colors.green.shade600;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 + 3.14159 * (20 / 40),
      3.14159 * (8 / 40),
      false,
      paint,
    );

    paint.color = Colors.red.shade700;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 + 3.14159 * (28 / 40),
      3.14159 * (12 / 40),
      false,
      paint,
    );

    // Draw needle
    final double clampWeight = currentWeight.clamp(0.0, 40.0);
    final double needleAngle = -3.14159 + (3.14159 * (clampWeight / 40.0));
    final needlePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + radius * 0.85 * math.cos(needleAngle),
      center.dy + radius * 0.85 * math.sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);

    // Draw cap
    final capPaint = Paint()..color = Colors.amber.shade800;
    canvas.drawCircle(center, 4, capPaint);
    capPaint.color = Colors.black;
    canvas.drawCircle(center, 1.5, capPaint);
  }

  @override
  bool shouldRepaint(covariant _WinchDialPainter oldDelegate) {
    return oldDelegate.currentWeight != currentWeight;
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

class _AstroDial extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final ValueChanged<double> onChanged;

  const _AstroDial({
    required this.label,
    required this.value,
    required this.target,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAligned = (value - target).abs() < 1;

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toInt()}°',
          style: TextStyle(
            color: isAligned ? Colors.greenAccent : Colors.amber.shade500,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        GestureDetector(
          onPanUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final center = box.size.center(Offset.zero);
            final localPos = details.localPosition;
            final rad = math.atan2(localPos.dy - center.dy, localPos.dx - center.dx);
            double deg = rad * 180 / math.pi;
            if (deg < 0) deg += 360;
            deg = (deg / 5).round() * 5.0;
            onChanged(deg);
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: value * math.pi / 180,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Colors.amber,
                        Colors.orange,
                        Color(0xFF2A1B0A),
                        Colors.amber,
                      ],
                    ),
                    border: Border.all(
                      color: isAligned ? Colors.greenAccent : Colors.amber.shade500,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 4,
                        child: Container(
                          width: 4,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isAligned ? Colors.greenAccent : Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.amber.shade900,
                          border: Border.all(color: Colors.amber.shade600, width: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.arrow_left, color: Colors.amber.shade600, size: 28),
              onPressed: isAligned
                  ? null
                  : () {
                      double newVal = (value - 5 + 360) % 360;
                      onChanged(newVal);
                    },
            ),
            const SizedBox(width: 8),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.arrow_right, color: Colors.amber.shade600, size: 28),
              onPressed: isAligned
                  ? null
                  : () {
                      double newVal = (value + 5) % 360;
                      onChanged(newVal);
                    },
            ),
          ],
        ),
      ],
    );
  }
}

class _TelescopeStarfieldPainter extends CustomPainter {
  final double angleMedved;
  final double angleVlk;
  final double angleJelen;

  _TelescopeStarfieldPainter({
    required this.angleMedved,
    required this.angleVlk,
    required this.angleJelen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gridPaint = Paint()
      ..color = Colors.amber.shade900.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, radius * 0.4, gridPaint);
    canvas.drawCircle(center, radius * 0.7, gridPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    final starPaint = Paint()..color = Colors.white.withOpacity(0.3);
    final randomStars = [
      Offset(radius * 0.3, radius * 0.4),
      Offset(radius * 1.5, radius * 0.5),
      Offset(radius * 0.5, radius * 1.6),
      Offset(radius * 1.6, radius * 1.4),
      Offset(radius * 1.2, radius * 0.3),
      Offset(radius * 0.4, radius * 1.2),
    ];
    for (var star in randomStars) {
      canvas.drawCircle(star, 1.5, starPaint);
    }

    _drawConstellation(
      canvas: canvas,
      center: center,
      currentAngle: angleMedved,
      targetAngle: 45,
      points: const [
        Offset(-30, -5), Offset(-15, -12), Offset(0, -8), Offset(12, 4),
        Offset(24, 20), Offset(8, 28), Offset(-12, 20)
      ],
      connections: const [
        [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]
      ],
      glowColor: Colors.cyanAccent,
    );

    _drawConstellation(
      canvas: canvas,
      center: center,
      currentAngle: angleVlk,
      targetAngle: 120,
      points: const [
        Offset(-25, 25), Offset(-8, 12), Offset(8, 8), Offset(25, -4),
        Offset(12, -20), Offset(-4, -16), Offset(-16, -4)
      ],
      connections: const [
        [0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 1], [5, 1]
      ],
      glowColor: Colors.tealAccent,
    );

    _drawConstellation(
      canvas: canvas,
      center: center,
      currentAngle: angleJelen,
      targetAngle: 275,
      points: const [
        Offset(-8, -30), Offset(8, -30), Offset(0, -16), Offset(0, 8),
        Offset(-20, 20), Offset(20, 20), Offset(-12, -4), Offset(12, -4)
      ],
      connections: const [
        [0, 2], [1, 2], [2, 3], [3, 4], [3, 5], [6, 3], [7, 3]
      ],
      glowColor: Colors.blueAccent,
    );
  }

  void _drawConstellation({
    required Canvas canvas,
    required Offset center,
    required double currentAngle,
    required double targetAngle,
    required List<Offset> points,
    required List<List<int>> connections,
    required Color glowColor,
  }) {
    final bool isAligned = (currentAngle - targetAngle).abs() < 1;

    final silhouettePaint = Paint()
      ..color = Colors.amber.shade900.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(targetAngle * math.pi / 180);
    for (var conn in connections) {
      canvas.drawLine(points[conn[0]], points[conn[1]], silhouettePaint);
    }
    for (var pt in points) {
      canvas.drawCircle(pt, 2.5, silhouettePaint);
    }
    canvas.restore();

    final linePaint = Paint()
      ..color = isAligned ? glowColor : Colors.white60
      ..style = PaintingStyle.stroke
      ..strokeWidth = isAligned ? 2.5 : 1.5;

    final starPaint = Paint()
      ..color = isAligned ? glowColor : Colors.white
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(currentAngle * math.pi / 180);

    for (var conn in connections) {
      canvas.drawLine(points[conn[0]], points[conn[1]], linePaint);
    }

    for (var pt in points) {
      if (isAligned) {
        final auraPaint = Paint()
          ..color = glowColor.withOpacity(0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pt, 7, auraPaint);
      }
      canvas.drawCircle(pt, isAligned ? 4.5 : 3.0, starPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TelescopeStarfieldPainter oldDelegate) {
    return oldDelegate.angleMedved != angleMedved ||
        oldDelegate.angleVlk != angleVlk ||
        oldDelegate.angleJelen != angleJelen;
  }
}


