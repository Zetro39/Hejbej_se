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

  // Balance Scales state
  final List<String> _leftPan = ['Jelen (25 kg)'];
  final List<String> _rightPan = [];
  final List<String> _availableWeights = ['Medvěd (15 kg)', 'Vlk (10 kg)', 'Liška (5 kg)'];

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
      // Balance is solved if left has Jelen (25) and right has Medved (15) + Vlk (10)
      final hasMedved = _rightPan.contains('Medvěd (15 kg)');
      final hasVlk = _rightPan.contains('Vlk (10 kg)');
      final hasLiska = _rightPan.contains('Liška (5 kg)');
      solved = (hasMedved && hasVlk && !hasLiska);
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
      title = "⚖️ Rovnováha vah lesa";
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
                    color: Colors.grey.shade850,
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
    // Total weight calculations
    int leftWeight = 25; // Jelen
    int rightWeight = 0;
    for (var w in _rightPan) {
      if (w.contains('15')) rightWeight += 15;
      if (w.contains('10')) rightWeight += 10;
      if (w.contains('5')) rightWeight += 5;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vyrovnej váhu oltáře bažin. Na levé misce leží kámen Jelena (25 kg). Přetáhni správné kameny lesní zvěře na pravou misku:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Visual Scales Representation
        Row(
          children: [
            // Left Pan
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade700, width: 2),
                ),
                child: Column(
                  children: [
                    const Text('Levá miska (Cíl)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    ..._leftPan.map((w) => Text(w, style: const TextStyle(color: Colors.lime, fontWeight: FontWeight.bold))),
                    const Spacer(),
                    Text('$leftWeight kg', style: const TextStyle(color: Colors.lime, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.swap_horiz, color: Colors.white, size: 36),
            const SizedBox(width: 16),
            // Right Pan
            Expanded(
              child: DragTarget<String>(
                onAccept: (val) {
                  setState(() {
                    _availableWeights.remove(val);
                    _rightPan.add(val);
                  });
                  _checkSolution();
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: rightWeight == leftWeight ? Colors.green : Colors.orange,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('Pravá miska', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        _rightPan.isEmpty
                            ? const Text('Prázdná (Zde hoď váhu)', style: TextStyle(color: Colors.white38, fontSize: 10))
                            : Column(
                                children: _rightPan.map((w) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _rightPan.remove(w);
                                        _availableWeights.add(w);
                                      });
                                    },
                                    child: Chip(
                                      label: Text(w, style: const TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.grey.shade800,
                                    ),
                                  );
                                }).toList(),
                              ),
                        const Spacer(),
                        Text('$rightWeight kg', style: TextStyle(color: rightWeight == leftWeight ? Colors.green : Colors.orange, fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Dostupná závaží (přetáhni na pravou misku):', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableWeights.map((w) {
            return Draggable<String>(
              data: w,
              feedback: Material(
                color: Colors.transparent,
                child: Chip(
                  label: Text(w),
                  backgroundColor: Colors.lime.shade700,
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.4,
                child: Chip(label: Text(w)),
              ),
              child: Chip(
                label: Text(w),
                backgroundColor: Colors.lightBlue.shade800,
              ),
            );
          }).toList(),
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
                      color: index % 2 == 0 ? Colors.red.shade900 : Colors.blue.shade950,
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
