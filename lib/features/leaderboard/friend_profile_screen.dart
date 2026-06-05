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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'PROFIL KAMARÁDA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: firestore.collection('users').doc(friendUid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
          final unlockedDistances = <double>[];
          for (final milestone in distanceMilestones) {
            if (totalDistance >= milestone) {
              unlockedDistances.add(milestone);
            }
          }

          final unlockedLoyalties = <int>[];
          for (final milestone in loyaltyMilestones) {
            if (streak >= milestone) {
              unlockedLoyalties.add(milestone);
            }
          }

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

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                // Avatar Card
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.lightBlue.shade100, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: Colors.lightBlue.shade50,
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
                                  ))
                            : const Icon(
                                Icons.person,
                                size: 80,
                                color: Colors.lightBlue,
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  fullName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                if (code.isNotEmpty)
                  Text(
                    code,
                    style: TextStyle(fontSize: 15, color: Colors.lightBlue.shade700, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 6),
                Text(
                  ageText,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 28),

                // Stats Section
                Row(
                  children: [
                    _buildStatCard(
                      icon: Icons.offline_bolt_outlined,
                      iconColor: Colors.amber,
                      value: '$limetky',
                      label: 'Limetky',
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.calendar_today_outlined,
                      iconColor: Colors.lightBlue,
                      value: '$streak dnů',
                      label: 'Série',
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      icon: Icons.directions_walk,
                      iconColor: Colors.lime.shade700,
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
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
                    return Card(
                      elevation: 2,
                      shadowColor: Colors.black12,
                      color: isUnlocked ? Colors.lime.shade50.withOpacity(0.4) : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isUnlocked ? Colors.lime.withOpacity(0.5) : Colors.grey.shade200,
                          width: 1,
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
                              color: isUnlocked ? Colors.lime.shade800 : Colors.grey.shade400,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ach['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? Colors.black87 : Colors.grey.shade500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ach['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: isUnlocked ? Colors.black54 : Colors.grey.shade400,
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
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
