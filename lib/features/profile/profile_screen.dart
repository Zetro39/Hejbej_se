import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../achievements/achievements_screen.dart';
import '../../login_screen.dart';

/// Modul Profil – uživatelské informace.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userName});

  final String userName;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  int limetkyBalance = 0;
  int streak = 0;
  double totalDistance = 0.0; // in km
  String? _selectedAvatar;
  List<bool> distanceAchievements = List.filled(6, false); // 1,10,100,1000,10000,40000 km
  List<bool> loyaltyAchievements = List.filled(3, false); // 10,50,250 days
  bool isStreakFrozen = false;

  final List<double> distanceMilestones = [1, 10, 100, 1000, 10000, 40000];
  final List<int> loyaltyMilestones = [10, 50, 250];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSelectedAvatar();
    _displayName = widget.userName;
    _loadProfileFromFirestore();
  }

  Future<void> _loadProfileFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};
      setState(() {
        if (data['first_name'] != null || data['last_name'] != null) {
          final fn = data['first_name'] as String? ?? '';
          final ln = data['last_name'] as String? ?? '';
          _displayName = '$fn $ln'.trim();
        } else if (data['username'] != null) {
          _displayName = data['username'] as String;
        }
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      limetkyBalance = prefs.getInt('limetkyBalance') ?? 0;
      streak = prefs.getInt('streak') ?? 0;
      totalDistance = prefs.getDouble('totalDistance') ?? 0.0;
      isStreakFrozen = prefs.getBool('isStreakFrozen') ?? false;
      for (int i = 0; i < distanceAchievements.length; i++) {
        distanceAchievements[i] = prefs.getBool('distanceAchievement_$i') ?? false;
      }
      for (int i = 0; i < loyaltyAchievements.length; i++) {
        loyaltyAchievements[i] = prefs.getBool('loyaltyAchievement_$i') ?? false;
      }
    });
    _updateAchievements();
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatar = prefs.getString('selected_avatar');
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('limetkyBalance', limetkyBalance);
    await prefs.setInt('streak', streak);
    await prefs.setDouble('totalDistance', totalDistance);
    await prefs.setBool('isStreakFrozen', isStreakFrozen);
    for (int i = 0; i < distanceAchievements.length; i++) {
      await prefs.setBool('distanceAchievement_$i', distanceAchievements[i]);
    }
    for (int i = 0; i < loyaltyAchievements.length; i++) {
      await prefs.setBool('loyaltyAchievement_$i', loyaltyAchievements[i]);
    }
  }

  void _updateAchievements() {
    // Update distance achievements
    for (int i = 0; i < distanceMilestones.length; i++) {
      if (totalDistance >= distanceMilestones[i] && !distanceAchievements[i]) {
        setState(() {
          distanceAchievements[i] = true;
        });
      }
    }
    // Update loyalty achievements
    for (int i = 0; i < loyaltyMilestones.length; i++) {
      if (streak >= loyaltyMilestones[i] && !loyaltyAchievements[i]) {
        setState(() {
          loyaltyAchievements[i] = true;
        });
      }
    }
    _saveData();
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    const storage = FlutterSecureStorage();
    await storage.deleteAll();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _streakLabel(int days) {
    return days == 1 ? 'Denní série: 1 den' : 'Denní série: $days dnů';
  }

  @override
  Widget build(BuildContext context) {
    final achievementItems = <Map<String, dynamic>>[];
    for (int i = 0; i < distanceMilestones.length; i++) {
      achievementItems.add({
        'title': '${distanceMilestones[i]} km',
        'unlocked': distanceAchievements[i],
        'type': 'distance',
        'value': distanceMilestones[i],
        'icon': Icons.directions_walk,
      });
    }
    for (int i = 0; i < loyaltyMilestones.length; i++) {
      achievementItems.add({
        'title': '${loyaltyMilestones[i]} dnů',
        'unlocked': loyaltyAchievements[i],
        'type': 'loyalty',
        'value': loyaltyMilestones[i].toDouble(),
        'icon': Icons.calendar_today,
      });
    }

    final visibleAchievements = List<Map<String, dynamic>>.from(achievementItems)
      ..sort((a, b) {
        final unlockedA = a['unlocked'] as bool ? 0 : 1;
        final unlockedB = b['unlocked'] as bool ? 0 : 1;
        if (unlockedA != unlockedB) return unlockedA - unlockedB;
        return (b['value'] as double).compareTo(a['value'] as double);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Úspěchy',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AchievementsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.lightBlue.shade50,
                  child: ClipOval(
                    child: _selectedAvatar != null
                        ? Image.asset(
                            'assets/images/${_selectedAvatar!}.png',
                            fit: BoxFit.cover,
                            width: 130,
                            height: 130,
                          )
                        : const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.lightBlue,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _streakLabel(streak),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.lightBlue.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Limetky',
                                  style: TextStyle(fontSize: 14, color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$limetkyBalance',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Denní série',
                                  style: TextStyle(fontSize: 14, color: Colors.black54),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$streak dnů',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isStreakFrozen) ...[
                          const SizedBox(height: 12),
                          const Text('Streak je momentálně zmrazený', style: TextStyle(color: Colors.blue)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Úspěchy',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: visibleAchievements
                      .take(4)
                      .map((item) => _AchievementCard(
                            title: item['title'] as String,
                            isUnlocked: item['unlocked'] as bool,
                            icon: item['icon'] as IconData,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AchievementsScreen(),
                        ),
                      );
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(Colors.lightBlue),
                      foregroundColor: WidgetStatePropertyAll(Colors.white),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 16)),
                    ),
                    child: const Text('Zobrazit všechny úspěchy'),
                  ),
                ),
                const SizedBox(height: 24),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 85.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(Colors.red.shade600),
                        foregroundColor: WidgetStatePropertyAll(Colors.white),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 18)),
                      ),
                      child: const Text(
                        'Odhlásit se',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'v1.2.3+41',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// Widget pro achievement kartu
class _AchievementCard extends StatelessWidget {
  final String title;
  final bool isUnlocked;
  final IconData icon;

  const _AchievementCard({
    required this.title,
    required this.isUnlocked,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isUnlocked ? Colors.lime.shade100 : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 40,
              color: isUnlocked ? Colors.lime.shade700 : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
