import 'package:flutter/material.dart';

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
      'id': 'chalice',
      'emoji': '🏆',
      'name': 'Rituální pohár',
      'description': 'Zlatý kalich z chrámu.',
      'weight': 8,
      'response': 'Tento masivní pohár ze zlata váží pěkných 8 kg.',
    },
    {
      'id': 'log',
      'emoji': '🪵',
      'name': 'Dubové poleno',
      'description': 'Kus tvrdého dřeva.',
      'weight': 6,
      'response': 'Pořádný kus dubového dřeva o váze 6 kg.',
    },
    {
      'id': 'anvil',
      'emoji': '🧱',
      'name': 'Stará kovadlina',
      'description': 'Masivní železná kovadlina.',
      'weight': 35,
      'response': 'Varování: Tahle kovadlina váží 35 kg! Lano studny tolik nikdy neunese!',
    },
    {
      'id': 'feathers',
      'emoji': '🪶',
      'name': 'Pytel peří',
      'description': 'Velký pytel plný peří.',
      'weight': 3,
      'response': 'Velký pytel husího peří. Váží 3 kg kvůli tlusté jutové látce.',
    },
    {
      'id': 'nails',
      'emoji': '⚙️',
      'name': 'Krabice hřebíků',
      'description': 'Kovové hřebíky a vruty.',
      'weight': 5,
      'response': 'Krabice plná rezavého spojovacího materiálu o váze 5 kg.',
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
      'id': 'spellbook',
      'emoji': '📜',
      'name': 'Kniha kouzel',
      'description': 'Tlustá kniha s kováním.',
      'weight': 4,
      'response': 'Tlustá kniha s těžkým kováním vážící 4 kg.',
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
    {
      'id': 'moss',
      'emoji': '🌿',
      'name': 'Lesní mech',
      'description': 'Vlhký trs mechu.',
      'weight': 2,
      'response': 'Vlhký mech nasáklý vodou váží 2 kg.',
    },
  ];

  // Bookshelf state
  final List<String> _books = ['Cyril', 'Ambrož', 'David', 'Bohumil'];
  final List<String> _correctBooksOrder = ['Ambrož', 'Bohumil', 'Cyril', 'David'];

  // Telescope state
  double _angleMedved = 0;
  double _angleVlk = 0;
  double _angleJelen = 0;

  bool _isSolved = false;

  void _checkSolution() {
    if (_isSolved) return;

    bool solved = false;

    if (widget.puzzleType == 'combination_lock') {
      final code = _dialValues.join();
      solved = (code == widget.correctCode);
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
    } else if (widget.puzzleType == 'telescope') {
      solved = (_angleMedved == 45 && _angleVlk == 120 && _angleJelen == 275);
    }

    if (solved) {
      setState(() {
        _isSolved = true;
      });
      Future.delayed(const Duration(milliseconds: 1200), () {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Zadej správnou trojmístnou kombinaci:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.lightBlue, width: 2),
              ),
              child: Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_up, color: Colors.white, size: 32),
                    onPressed: () {
                      setState(() {
                        _dialValues[index] = (_dialValues[index] + 1) % 10;
                      });
                      _checkSolution();
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Text(
                      _dialValues[index].toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 32),
                    onPressed: () {
                      setState(() {
                        _dialValues[index] = (_dialValues[index] - 1 + 10) % 10;
                      });
                      _checkSolution();
                    },
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        const Text(
          'Nápovědu najdeš v hajného sešitě.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ],
    );
  }

  // 2. Balance Scales Widget
  Widget _buildScales() {
    int totalWeight = 0;
    for (var itemId in _selectedWinchItems) {
      final item = _winchItems.firstWhere((it) => it['id'] == itemId);
      totalWeight += item['weight'] as int;
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
          'Vyvaž naviják studny. Kbelík váží 20 kg. Musíš na pravou plošinu naložit 21 až 28 kg, aby vyjel nahoru. Pozor, lano unese nejvýše 28 kg!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade300, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),

        // 2. The Interactive Altar & Well (Winch Area)
        Container(
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

              // Winch Dial/Indicator (Shows current load)
              Positioned(
                left: 110,
                top: 8,
                right: 130,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black80,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade600, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Zátěž: ', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text(
                        '$totalWeight kg',
                        style: TextStyle(
                          color: totalWeight > 28
                              ? Colors.redAccent
                              : totalWeight > 20
                                  ? Colors.greenAccent
                                  : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
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
                                _checkSolution();
                              } else {
                                setState(() {
                                  _winchState = 'snapped';
                                  _winchFeedbackText = 'KŘUP! Plošina s váhou $totalWeight kg byla moc těžká! Lano nevydrželo nápor a prasklo!';
                                });
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
        const SizedBox(height: 12),

        // 3. Feedback Dialog Bubble from Hero
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade855,
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

        // 5. Scrollable Grid of 15 Available items
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

                return GestureDetector(
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
                              } else {
                                _selectedWinchItems.add(itemId);
                                _winchFeedbackText = item['response'] as String;
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
                            ? [Colors.amber.shade900, Colors.amber.shade955]
                            : [Colors.grey.shade850, Colors.grey.shade900],
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
                          '${item['weight']} kg',
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Seřaď svazky knih abecedně od A do Z tak, aby se aktivoval mechanismus:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 24),
        // Visual representation of books
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.brown.shade800,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.brown.shade900, width: 4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_books.length, (index) {
              final bookName = _books[index];
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    // Tap a book to swap with the next one
                    if (index < _books.length - 1) {
                      setState(() {
                        final temp = _books[index];
                        _books[index] = _books[index + 1];
                        _books[index + 1] = temp;
                      });
                      _checkSolution();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 140,
                    decoration: BoxDecoration(
                      color: index % 2 == 0 ? Colors.red.shade900 : Colors.blue.shade900,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.yellow.shade800, width: 2),
                    ),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Text(
                          bookName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Kliknutím na knihu ji prohodíš s knihou napravo.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  // 4. Telescope Widget
  Widget _buildTelescope() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Zaměř dalekohled na správné úhly souhvězdí podle Poustevníkových indicií:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),

        // 1. Medved (45 deg)
        _buildAngleSlider(
          label: '🐻 Souhvězdí Medvěda',
          value: _angleMedved,
          target: 45,
          onChanged: (val) {
            setState(() {
              _angleMedved = val;
            });
            _checkSolution();
          },
        ),

        // 2. Vlk (120 deg)
        _buildAngleSlider(
          label: '🐺 Souhvězdí Vlka',
          value: _angleVlk,
          target: 120,
          onChanged: (val) {
            setState(() {
              _angleVlk = val;
            });
            _checkSolution();
          },
        ),

        // 3. Jelen (275 deg)
        _buildAngleSlider(
          label: '🦌 Souhvězdí Jelena',
          value: _angleJelen,
          target: 275,
          onChanged: (val) {
            setState(() {
              _angleJelen = val;
            });
            _checkSolution();
          },
        ),
      ],
    );
  }

  Widget _buildAngleSlider({
    required String label,
    required double value,
    required double target,
    required ValueChanged<double> onChanged,
  }) {
    final isAligned = value == target;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                '${value.toInt()}° ' + (isAligned ? '✅ (Zaměřeno)' : ''),
                style: TextStyle(
                  color: isAligned ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0,
            max: 360,
            divisions: 72, // 5 degree steps
            activeColor: isAligned ? Colors.green : Colors.lime,
            inactiveColor: Colors.grey.shade800,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
