import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../achievements/achievements_screen.dart';

/// Modul Profil – uživatelské informace.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userName});

  final String userName;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int limetkyBalance = 0;
  int streak = 0;
  double totalDistance = 0.0; // in km
  List<bool> distanceAchievements = List.filled(6, false); // 1,10,100,1000,10000,40000 km
  List<bool> loyaltyAchievements = List.filled(3, false); // 10,50,250 days
  bool isStreakFrozen = false;

  final List<double> distanceMilestones = [1, 10, 100, 1000, 10000, 40000];
  final List<int> loyaltyMilestones = [10, 50, 250];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _initializePayClient() async {
    try {
      final appleConfig = await PaymentConfiguration.fromAsset('apple_pay_config.json');
      final googleConfig = await PaymentConfiguration.fromAsset('google_pay_config.json');
      _payClient = Pay({
        PayProvider.apple_pay: appleConfig,
        PayProvider.google_pay: googleConfig,
      });
      final appleAvailable = await _payClient.userCanPay(PayProvider.apple_pay);
      if (!mounted) return;
      setState(() {
        _applePayConfig = appleConfig;
        _googlePayConfig = googleConfig;
        _applePayAvailable = appleAvailable;
        _paymentReady = true;
      });
    } catch (e) {
      debugPrint('Payment initialization failed: $e');
      if (!mounted) return;
      setState(() {
        _paymentReady = true;
      });
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

  void _buyJoker() {
    if (limetkyBalance >= 100) {
      setState(() {
        limetkyBalance -= 100;
        isStreakFrozen = true;
      });
      _saveData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Žolík zakoupen! Streak zmrazen.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nedostatek Limetků!')),
      );
    }
  }

  // Simulate adding distance for testing
  void _addDistance(double km) {
    setState(() {
      totalDistance += km;
      limetkyBalance += km.toInt(); // 1 km = 1 Limetka
    });
    _updateAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.badge),
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

                // Kruhový prostor pro fotku
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.lightBlue, Colors.lime],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Jméno uživatele
                Text(
                  widget.userName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),

                const SizedBox(height: 8),

                // Status
                Text(
                  'Hrdina',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.lightBlue.shade600,
                      ),
                ),

                const SizedBox(height: 20),

                // Limetky Balance
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.monetization_on, color: Color(0xFFBFFF00), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Limetky: $limetkyBalance',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Streak
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Streak: $streak dnů',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isStreakFrozen) const Text('Zmrazeno', style: TextStyle(color: Colors.blue)),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _buyJoker,
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(const Color(0xFFBFFF00)),
                            foregroundColor: MaterialStateProperty.all(Colors.black),
                          ),
                          child: const Text('Koupit Žolíka (100 Limetků)'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Total Distance
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Celková vzdálenost: ${totalDistance.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Achievements Grid
                const Text(
                  'Úspěchy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Distance Achievements
                    for (int i = 0; i < distanceMilestones.length; i++)
                      _AchievementCard(
                        title: '${distanceMilestones[i]} km',
                        isUnlocked: distanceAchievements[i],
                        icon: Icons.directions_walk,
                      ),
                    // Loyalty Achievements
                    for (int i = 0; i < loyaltyMilestones.length; i++)
                      _AchievementCard(
                        title: '${loyaltyMilestones[i]} dnů',
                        isUnlocked: loyaltyAchievements[i],
                        icon: Icons.calendar_today,
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Test button to add distance
                ElevatedButton(
                  onPressed: () => _addDistance(1.0),
                  child: const Text('Přidat 1 km (test)'),
                ),

                const SizedBox(height: 20),

                // Donations Section
                const Text(
                  'Podpořte vývoj Hejbej se',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
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
