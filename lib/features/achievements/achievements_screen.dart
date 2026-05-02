import 'dart:math';

import 'package:flutter/material.dart';

const List<Map<String, dynamic>> _achievementData = [
  {
    'asset': 'assets/images/Atchivment_1km.png',
    'title': 'První kilometr',
    'description': 'Ujdi 1 km a odemkni první odznak',
    'goal': 1.0,
  },
  {
    'asset': 'assets/images/Atchivment_10km.png',
    'title': 'Deset kilometrů',
    'description': 'Ujdi 10 km a získej další odznak',
    'goal': 10.0,
  },
  {
    'asset': 'assets/images/Atchivment_100km.png',
    'title': 'Sto kilometrů',
    'description': 'Ujdi 100 km a slav svůj pokrok',
    'goal': 100.0,
  },
  {
    'asset': 'assets/images/Atchivment_1000km.png',
    'title': 'Tisíc kilometrů',
    'description': 'Ujdi 1 000 km a dostaň speciální medaili',
    'goal': 1000.0,
  },
  {
    'asset': 'assets/images/Atchivment_10000km.png',
    'title': 'Deset tisíc kilometrů',
    'description': 'Ujdi 10 000 km a získej mistrovský odznak',
    'goal': 10000.0,
  },
  {
    'asset': 'assets/images/Atchivment_40000km.png',
    'title': 'Cesta kolem světa',
    'description': 'Ujdi 40 000 km a dohledej slávu',
    'goal': 40000.0,
  },
];

const List<double> _grayscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  double _totalDistance = 12345.0;
  late final TextEditingController _distanceController;

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController(text: _totalDistance.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  void _updateDistance(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null) {
      setState(() {
        _totalDistance = parsed.clamp(0, 40000);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Úspěchy'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Testovací vzdálenost',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _totalDistance.clamp(0, 40000),
                            min: 0,
                            max: 40000,
                            divisions: 40,
                            label: '${_totalDistance.round()} km',
                            activeColor: Colors.lime,
                            inactiveColor: Colors.lightBlue.shade100,
                            onChanged: (value) {
                              setState(() {
                                _totalDistance = value;
                                _distanceController.text = value.round().toString();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_totalDistance.round()} km',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.lightBlue.shade900,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _distanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: false),
                      decoration: InputDecoration(
                        labelText: 'Ruční zadání km',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.directions_walk),
                      ),
                      onSubmitted: _updateDistance,
                      onChanged: (value) {
                        final parsed = double.tryParse(value.replaceAll(',', '.'));
                        if (parsed != null) {
                          setState(() {
                            _totalDistance = parsed.clamp(0, 40000);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _achievementData.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final item = _achievementData[index];
                  final double goal = item['goal'] as double;
                  final double progress = min(_totalDistance / goal, 1.0);
                  final bool reached = _totalDistance >= goal;
                  final String title = item['title'] as String;
                  final String description = item['description'] as String;
                  final String asset = item['asset'] as String;
                  final int percentage = (progress * 100).round();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ColorFiltered(
                                colorFilter: ColorFilter.matrix(
                                  reached
                                      ? const <double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
                                      : _grayscaleMatrix,
                                ),
                                child: Image.asset(
                                  asset,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      description,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.black54,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 10,
                                        backgroundColor: Colors.lightBlue.shade100,
                                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.lime),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$percentage%',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: reached ? Colors.lime.shade900 : Colors.black38,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
