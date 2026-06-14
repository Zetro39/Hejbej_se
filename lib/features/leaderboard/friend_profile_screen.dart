import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({super.key, required this.friendUid});

  final String friendUid;

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final List<double> distanceMilestones = [1.0, 10.0, 100.0, 1000.0, 10000.0, 40000.0];
    final List<int> loyaltyMilestones = [10, 50, 250];

    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: const Text(
          'PROFIL KAMARÁDA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E272C),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('users').doc(friendUid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFBFFF00)));
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Nepodařilo se načíst profil kamaráda.',
                style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final username = data['username'] as String? ?? 'Uživatel';
          final code = data['friend_code'] as String? ?? '';
          final firstName = data['first_name'] as String? ?? '';
          final lastName = data['last_name'] as String? ?? '';
          final fullName = '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName';
          
          final limetky = data['limetky'] as int? ?? 0;
          final streak = data['streak'] as int? ?? 0;
          final totalDistance = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;

          final avatar = data['selected_avatar'] as String?;
          final birthDateTs = data['birth_date'] as Timestamp?;
          
          String ageText = 'Věk: neuveden';
          if (birthDateTs != null) {
            ageText = 'Věk: ${_calculateAge(birthDateTs.toDate())} let';
          }

          // Compute achievements
          final achievements = <Map<String, dynamic>>[];
          for (int i = 0; i < distanceMilestones.length; i++) {
            achievements.add({
              'title': '${distanceMilestones[i].toStringAsFixed(0)} km',
              'subtitle': 'Ujít celkem ${distanceMilestones[i].toStringAsFixed(0)} km',
              'unlocked': totalDistance >= distanceMilestones[i],
              'icon': Icons.directions_walk,
            });
          }
          for (int i = 0; i < loyaltyMilestones.length; i++) {
            achievements.add({
              'title': '${loyaltyMilestones[i]} dnů',
              'subtitle': 'Dosáhnout série ${loyaltyMilestones[i]} dnů',
              'unlocked': streak >= loyaltyMilestones[i],
              'icon': Icons.calendar_today,
            });
          }
          final completedLostAmulet = data['achievement_hero_lost_amulet'] as bool? ?? false;
          achievements.add({
            'title': 'Cesta živlů',
            'subtitle': 'Dokončit příběh Cesta živlů',
            'unlocked': completedLostAmulet,
            'icon': Icons.auto_stories,
          });

          final completedEasy = data['achievement_story_difficulty_easy'] as bool? ?? false;
          final completedMedium = data['achievement_story_difficulty_medium'] as bool? ?? false;
          final completedHard = data['achievement_story_difficulty_hard'] as bool? ?? false;
          final completedHardcore = data['achievement_story_difficulty_hardcore'] as bool? ?? false;

          achievements.add({
            'title': 'Lehká trasa',
            'subtitle': 'Příběh na lehkou obtížnost',
            'unlocked': completedEasy,
            'icon': Icons.explore,
          });
          achievements.add({
            'title': 'Střední trasa',
            'subtitle': 'Příběh na střední obtížnost',
            'unlocked': completedMedium,
            'icon': Icons.explore,
          });
          achievements.add({
            'title': 'Těžká trasa',
            'subtitle': 'Příběh na těžkou obtížnost',
            'unlocked': completedHard,
            'icon': Icons.explore,
          });
          achievements.add({
            'title': 'Hardcore trasa',
            'subtitle': 'Příběh na hardcore obtížnost',
            'unlocked': completedHardcore,
            'icon': Icons.explore,
          });

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                
                // Avatar container with Neon Lime glowing border
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFBFFF00), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBFFF00).withOpacity(0.15),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: const Color(0xFF1E272C),
                      child: ClipOval(
                        child: avatar != null
                            ? (avatar.startsWith('base64:')
                                ? Image.memory(
                                    base64Decode(avatar.substring(7)),
                                    fit: BoxFit.cover,
                                    width: 128,
                                    height: 128,
                                  )
                                : Image.asset(
                                    'assets/images/$avatar.png',
                                    fit: BoxFit.cover,
                                    width: 128,
                                    height: 128,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.person,
                                        size: 80,
                                        color: Colors.white54,
                                      );
                                    },
                                  ))
                            : const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.white54,
                              ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                Text(
                  fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                if (code.isNotEmpty)
                  Text(
                    code,
                    style: const TextStyle(fontSize: 15, color: Color(0xFFBFFF00), fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                Text(
                  ageText,
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 28),

                // Stats Section
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.offline_bolt_outlined,
                      iconColor: const Color(0xFFBFFF00),
                      value: '$limetky',
                      label: 'Limetky',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.white,
                      value: '$streak dní',
                      label: 'Série',
                    ),
                    const SizedBox(width: 10),
                    _buildStatCard(
                      icon: Icons.directions_walk,
                      iconColor: const Color(0xFF1B5E20),
                      value: '${totalDistance.toStringAsFixed(1)} km',
                      label: 'Celkem',
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Úspěchy kamaráda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),

                // Achievements Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final ach = achievements[index];
                    final isUnlocked = ach['unlocked'] as bool;
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: isUnlocked 
                            ? const Color(0xFF1B5E20).withOpacity(0.3)
                            : const Color(0xFF1E272C),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isUnlocked ? const Color(0xFFBFFF00).withOpacity(0.5) : Colors.white12,
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              ach['icon'] as IconData,
                              size: 32,
                              color: isUnlocked ? const Color(0xFFBFFF00) : Colors.white30,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ach['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? Colors.white : Colors.white30,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ach['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: isUnlocked ? Colors.white70 : Colors.white38,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E272C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
