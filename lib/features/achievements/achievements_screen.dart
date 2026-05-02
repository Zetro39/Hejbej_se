import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/location_service.dart';

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
  {
    'id': 'checkpoint_1',
    'title': 'První checkpoint',
    'description': 'Najdi a dosáhni severovýchodní checkpoint',
    'type': 'checkpoint',
  },
  {
    'id': 'checkpoint_2',
    'title': 'Druhý checkpoint',
    'description': 'Najdi a dosáhni jižovýchodní checkpoint',
    'type': 'checkpoint',
  },
  {
    'id': 'checkpoint_3',
    'title': 'Třetí checkpoint',
    'description': 'Najdi a dosáhni jihozápadní checkpoint',
    'type': 'checkpoint',
  },
  {
    'id': 'checkpoint_4',
    'title': 'Čtvrtý checkpoint',
    'description': 'Najdi a dosáhni severozápadní checkpoint',
    'type': 'checkpoint',
  },
  {
    'id': 'checkpoint_5',
    'title': 'Pátý checkpoint',
    'description': 'Najdi a dosáhni východní checkpoint',
    'type': 'checkpoint',
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
  late final DistanceManager _distanceManager;
  late final TextEditingController _distanceController;
  bool _debugMode = false;
  bool _checkpoint1Reached = false;
  bool _checkpoint2Reached = false;
  bool _checkpoint3Reached = false;
  bool _checkpoint4Reached = false;
  bool _checkpoint5Reached = false;

  @override
  void initState() {
    super.initState();
    _distanceManager = DistanceManager();
    _distanceController = TextEditingController(
      text: _distanceManager.totalDistance.toStringAsFixed(0),
    );
    _loadCheckpointAchievements();
  }

  Future<void> _loadCheckpointAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _checkpoint1Reached = prefs.getBool('achievement_checkpoint_1_reached') ?? false;
      _checkpoint2Reached = prefs.getBool('achievement_checkpoint_2_reached') ?? false;
      _checkpoint3Reached = prefs.getBool('achievement_checkpoint_3_reached') ?? false;
      _checkpoint4Reached = prefs.getBool('achievement_checkpoint_4_reached') ?? false;
      _checkpoint5Reached = prefs.getBool('achievement_checkpoint_5_reached') ?? false;
    });
  }

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  void _updateDistance(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null) {
      _distanceManager.setDistance(parsed);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = _distanceManager.totalDistance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Úspěchy'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_debugMode ? Icons.bug_report : Icons.bug_report_outlined),
            tooltip: 'Debug mode',
            onPressed: () {
              setState(() {
                _debugMode = !_debugMode;
              });
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // Debug mode distance tester
            if (_debugMode)
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
                        'Debug: Testovací vzdálenost',
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
                              value: totalDistance.clamp(0, 40000),
                              min: 0,
                              max: 40000,
                              divisions: 40,
                              label: '${totalDistance.round()} km',
                              activeColor: Colors.lime,
                              inactiveColor: Colors.lightBlue.shade100,
                              onChanged: (value) {
                                _distanceManager.setDistance(value);
                                _distanceController.text = value.round().toString();
                                setState(() {});
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${totalDistance.round()} km',
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
                            _distanceManager.setDistance(parsed);
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (_debugMode) const SizedBox(height: 16),
            // Real GPS distance display
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.lightBlue),
                        const SizedBox(width: 8),
                        Text(
                          'Celková vzdálenost:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      '${totalDistance.toStringAsFixed(2)} km',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.lime.shade900,
                          ),
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
                  
                  // Handle checkpoint achievements
                  if (item['type'] == 'checkpoint') {
                    final String id = item['id'] as String;
                    final bool reached = (id == 'checkpoint_1' ? _checkpoint1Reached :
                                         id == 'checkpoint_2' ? _checkpoint2Reached :
                                         id == 'checkpoint_3' ? _checkpoint3Reached :
                                         id == 'checkpoint_4' ? _checkpoint4Reached :
                                         id == 'checkpoint_5' ? _checkpoint5Reached : false);
                    final String title = item['title'] as String;
                    final String description = item['description'] as String;
                    
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
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: reached ? Colors.lime.shade100 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    reached ? Icons.check_circle : Icons.flag,
                                    size: 48,
                                    color: reached ? Colors.lime.shade700 : Colors.grey,
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: reached ? Colors.lime.shade100 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          reached ? 'Dosaženo' : 'Nedosaženo',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: reached ? Colors.lime.shade900 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Handle distance-based achievements
                  final double goal = item['goal'] as double;
                  final double progress = min(totalDistance / goal, 1.0);
                  final bool reached = totalDistance >= goal;
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