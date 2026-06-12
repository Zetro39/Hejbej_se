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

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final DistanceManager _distanceManager;
  final List<bool> _loyaltyAchievements = [false, false, false];
  final List<bool> _stepsAchievements = List.filled(6, false);
  bool _storyAmuletCompleted = false;
  bool _storyDifficultyEasy = false;
  bool _storyDifficultyMedium = false;
  bool _storyDifficultyHard = false;
  bool _storyDifficultyHardcore = false;
  final Map<String, bool> _checkpointAchievements = {};

  @override
  void initState() {
    super.initState();
    _distanceManager = DistanceManager();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _loyaltyAchievements[0] = prefs.getBool('loyaltyAchievement_0') ?? false;
      _loyaltyAchievements[1] = prefs.getBool('loyaltyAchievement_1') ?? false;
      _loyaltyAchievements[2] = prefs.getBool('loyaltyAchievement_2') ?? false;

      final milestones = [5, 10, 25, 50, 100, 365];
      for (int i = 0; i < milestones.length; i++) {
        _stepsAchievements[i] = prefs.getBool('steps_achievement_${milestones[i]}') ?? false;
      }

      _storyAmuletCompleted = prefs.getBool('achievement_hero_lost_amulet') ?? false;
      _storyDifficultyEasy = prefs.getBool('achievement_story_difficulty_easy') ?? false;
      _storyDifficultyMedium = prefs.getBool('achievement_story_difficulty_medium') ?? false;
      _storyDifficultyHard = prefs.getBool('achievement_story_difficulty_hard') ?? false;
      _storyDifficultyHardcore = prefs.getBool('achievement_story_difficulty_hardcore') ?? false;

      for (int i = 1; i <= 5; i++) {
        _checkpointAchievements['checkpoint_$i'] = prefs.getBool('achievement_checkpoint_${i}_reached') ?? false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalDistance = _distanceManager.totalDistance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Úspěchy'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12.0),
            child: Icon(Icons.emoji_events, color: Colors.white),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            // Achievement sections
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  ExpansionTile(
                    leading: const Icon(Icons.directions_walk, color: Colors.lightBlue),
                    title: const Text('Užité kilometry'),
                    children: _achievementData
                        .where((item) => item.containsKey('goal'))
                        .map((item) {
                          final goal = item['goal'] as double;
                          final reached = totalDistance >= goal;
                          final progress = min(totalDistance / goal, 1.0);
                          return ListTile(
                            leading: Icon(
                              reached ? Icons.check_circle : Icons.watch_later,
                              color: reached ? Colors.lime : Colors.grey,
                            ),
                            title: Text('${item['title']}'),
                            subtitle: Text(item['description'] as String),
                            trailing: Text(
                              '${(progress * 100).round()}%',
                              style: TextStyle(
                                color: reached ? Colors.lime.shade900 : Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.calendar_today, color: Colors.lightBlue),
                    title: const Text('Denní série'),
                    children: [
                      _buildSectionTile('10 dnů', _loyaltyAchievements[0]),
                      _buildSectionTile('50 dnů', _loyaltyAchievements[1]),
                      _buildSectionTile('250 dnů', _loyaltyAchievements[2]),
                    ],
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.lightBlue),
                    title: const Text('Svědomitý (Plnění krokového cíle)'),
                    children: [
                      _buildSectionTile('5 dní plnění cíle', _stepsAchievements[0]),
                      _buildSectionTile('10 dní plnění cíle', _stepsAchievements[1]),
                      _buildSectionTile('25 dní plnění cíle', _stepsAchievements[2]),
                      _buildSectionTile('50 dní plnění cíle', _stepsAchievements[3]),
                      _buildSectionTile('100 dní plnění cíle', _stepsAchievements[4]),
                      _buildSectionTile('365 dní plnění cíle', _stepsAchievements[5]),
                    ],
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.map, color: Colors.lightBlue),
                    title: const Text('Objevitel (Checkpointy)'),
                    children: _achievementData
                        .where((item) => item['type'] == 'checkpoint')
                        .map((item) {
                          final id = item['id'] as String;
                          final reached = _checkpointAchievements[id] ?? false;
                          return ListTile(
                            leading: Icon(
                              reached ? Icons.emoji_events : Icons.lock_outline,
                              color: reached ? Colors.lime : Colors.grey,
                            ),
                            title: Text('${item['title']}'),
                            subtitle: Text(item['description'] as String),
                          );
                        })
                        .toList(),
                  ),
                  ExpansionTile(
                    leading: const Icon(Icons.explore, color: Colors.lightBlue),
                    title: const Text('Příběhové výpravy'),
                    children: [
                      _buildStoryTile(
                        'Ztracený amulet',
                        'Dokonči celou příběhovou linku Ztracený amulet.',
                        _storyAmuletCompleted,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _buildStoryDifficultyTile(
                        'Pohodový poutník (Lehká)',
                        'Dokonči příběh na lehkou obtížnost (6 km).',
                        _storyDifficultyEasy,
                        Colors.green,
                      ),
                      _buildStoryDifficultyTile(
                        'Zkušený dobrodruh (Střední)',
                        'Dokonči příběh na střední obtížnost (10 km).',
                        _storyDifficultyMedium,
                        Colors.cyan,
                      ),
                      _buildStoryDifficultyTile(
                        'Vytrvalý hrdina (Těžká)',
                        'Dokonči příběh na těžkou obtížnost (15 km).',
                        _storyDifficultyHard,
                        Colors.orange,
                      ),
                      _buildStoryDifficultyTile(
                        'Legenda z bažin (Hardcore)',
                        'Dokonči příběh na hardcore obtížnost (20 km)!',
                        _storyDifficultyHardcore,
                        Colors.redAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTile(String title, bool unlocked) {
    return ListTile(
      leading: Icon(unlocked ? Icons.emoji_events : Icons.lock_outline,
          color: unlocked ? Colors.lime : Colors.grey),
      title: Text(title),
      subtitle: Text(unlocked ? 'Odemčeno' : 'Ještě nedosaženo'),
    );
  }

  Widget _buildStoryTile(String title, String description, bool unlocked) {
    return ListTile(
      leading: Icon(
        unlocked ? Icons.auto_stories : Icons.auto_stories_outlined,
        color: unlocked ? Colors.deepPurple : Colors.grey,
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: unlocked ? Colors.black87 : Colors.black54,
        ),
      ),
      subtitle: Text(description),
      trailing: Text(
        unlocked ? '100%' : '0%',
        style: TextStyle(
          color: unlocked ? Colors.deepPurple.shade900 : Colors.black54,
          fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildStoryDifficultyTile(String title, String description, bool unlocked, Color activeColor) {
    return ListTile(
      leading: Icon(
        unlocked ? Icons.emoji_events : Icons.lock_outline,
        color: unlocked ? activeColor : Colors.grey,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: unlocked ? Colors.black87 : Colors.black54,
        ),
      ),
      subtitle: Text(description),
      trailing: Text(
        unlocked ? '100%' : '0%',
        style: TextStyle(
          color: unlocked ? activeColor : Colors.black54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}