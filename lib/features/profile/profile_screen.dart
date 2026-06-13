import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../achievements/achievements_screen.dart';
import '../../login_screen.dart';
import '../../services/step_tracker_service.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _storyAmuletCompleted = false;
  bool _storyDifficultyEasy = false;
  bool _storyDifficultyMedium = false;
  bool _storyDifficultyHard = false;
  bool _storyDifficultyHardcore = false;

  String _firstName = '';
  String _lastName = '';
  String _username = '';
  int _dailyStepsGoal = 10000;
  Timestamp? _lastUsernameChange;
  Timestamp? _usernameGracePeriodEnd;
  List<String> _stepsGoalHistory = [];
  int _stepsStreak = 0;

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
        _firstName = data['first_name'] as String? ?? '';
        _lastName = data['last_name'] as String? ?? '';
        _username = data['username'] as String? ?? '';
        _dailyStepsGoal = data['daily_steps_goal'] as int? ?? 10000;
        _lastUsernameChange = data['last_username_change'] as Timestamp?;
        _usernameGracePeriodEnd = data['username_grace_period_end'] as Timestamp?;
        final firestoreHistory = List<String>.from(data['steps_goal_history'] ?? []);
        _stepsGoalHistory = {..._stepsGoalHistory, ...firestoreHistory}.toList();
        
        final firestoreStreak = data['steps_streak'] as int? ?? 0;
        if (firestoreStreak > _stepsStreak) {
          _stepsStreak = firestoreStreak;
        }

        SharedPreferences.getInstance().then((prefs) {
          prefs.setStringList('steps_goal_history', _stepsGoalHistory);
          prefs.setInt('steps_streak', _stepsStreak);
        });

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
      _stepsGoalHistory = prefs.getStringList('steps_goal_history') ?? [];
      _stepsStreak = prefs.getInt('steps_streak') ?? 0;
      _storyAmuletCompleted = prefs.getBool('achievement_hero_lost_amulet') ?? false;
      _storyDifficultyEasy = prefs.getBool('achievement_story_difficulty_easy') ?? false;
      _storyDifficultyMedium = prefs.getBool('achievement_story_difficulty_medium') ?? false;
      _storyDifficultyHard = prefs.getBool('achievement_story_difficulty_hard') ?? false;
      _storyDifficultyHardcore = prefs.getBool('achievement_story_difficulty_hardcore') ?? false;
    });
    _updateAchievements();
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatar = prefs.getString('selected_avatar');
    });
  }

  Future<void> _changeAvatar() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E272C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Změnit profilový obrázek',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Color(0xFFBFFF00)),
                  title: const Text('Vybrat z galerie', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickCustomAvatar();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.face, color: Color(0xFFBFFF00)),
                  title: const Text('Vybrat přednastaveného avatara', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.pop(context);
                    _showPresetsDialog();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCustomAvatar() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 150,
        maxHeight: 150,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      final avatarId = 'base64:$base64String';
      
      await _updateAvatarStateAndDatabase(avatarId);
    } catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  void _showPresetsDialog() {
    final presets = [
      {'id': 'boy', 'name': 'Chlapec', 'asset': 'assets/images/boy.png'},
      {'id': 'girl', 'name': 'Dívka', 'asset': 'assets/images/girl.png'},
      {'id': 'man', 'name': 'Muž', 'asset': 'assets/images/man.png'},
      {'id': 'chlap', 'name': 'Chlap', 'asset': 'assets/images/chlap.png'},
      {'id': 'woman', 'name': 'Žena', 'asset': 'assets/images/woman.png'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF37474F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Přednastavení avataři', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _updateAvatarStateAndDatabase(preset['id']!);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            preset['asset']!,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset['name']!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateAvatarStateAndDatabase(String avatarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_avatar', avatarId);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'selected_avatar': avatarId,
        });
      } catch (_) {}
    }
    
    setState(() {
      _selectedAvatar = avatarId;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilový obrázek byl změněn.')),
      );
    }
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

  String _cleanStringForSearch(String input) {
    var str = input.toLowerCase().trim();
    const diacritics = {
      'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n', 
      'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z'
    };
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      buffer.write(diacritics[char] ?? char);
    }
    return buffer.toString().replaceAll('#', '');
  }

  void _showEditProfileDialog() {
    final usernameController = TextEditingController(text: _username);
    int tempGoal = _dailyStepsGoal;
    bool isSaving = false;
    String? errorText;

    // Check if username change is locked
    final now = DateTime.now();
    bool canChangeUsername = true;
    DateTime? nextChangePossible;
    bool inGracePeriod = false;

    if (_lastUsernameChange != null) {
      final lastChange = _lastUsernameChange!.toDate();
      final graceEnd = _usernameGracePeriodEnd?.toDate() ?? lastChange.add(const Duration(minutes: 10));
      
      if (now.isBefore(graceEnd)) {
        inGracePeriod = true;
      } else {
        final daysSinceChange = now.difference(lastChange).inDays;
        if (daysSinceChange < 30) {
          canChangeUsername = false;
          nextChangePossible = lastChange.add(const Duration(days: 30));
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('⚙️ Upravit profil', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: TextEditingController(text: _firstName),
                      decoration: const InputDecoration(
                        labelText: 'Jméno (nelze měnit)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: TextEditingController(text: _lastName),
                      decoration: const InputDecoration(
                        labelText: 'Příjmení (nelze měnit)',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: usernameController,
                      decoration: InputDecoration(
                        labelText: 'Herní přezdívka',
                        prefixIcon: const Icon(Icons.alternate_email),
                        errorText: errorText,
                        helperText: inGracePeriod
                            ? 'Ochranná lhůta na opravu překlepů je aktivní.'
                            : !canChangeUsername
                                ? 'Změna bude možná od ${nextChangePossible?.day}. ${nextChangePossible?.month}. ${nextChangePossible?.year}'
                                : 'Lze změnit jednou za 30 dní.',
                      ),
                      enabled: canChangeUsername || inGracePeriod,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '🎯 Denní cíl kroků: ${tempGoal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} ")}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Slider(
                      value: tempGoal.toDouble(),
                      min: 1000.0,
                      max: 30000.0,
                      divisions: 29,
                      activeColor: Colors.lightBlue,
                      inactiveColor: Colors.lightBlue.shade100,
                      onChanged: (v) {
                        setDialogState(() {
                          tempGoal = v.toInt();
                        });
                      },
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator(color: Colors.lightBlue)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    final enteredUsername = usernameController.text.trim();
                    if (enteredUsername.isEmpty) {
                      setDialogState(() {
                        errorText = 'Přezdívka nesmí být prázdná';
                      });
                      return;
                    }

                    setDialogState(() {
                      isSaving = true;
                      errorText = null;
                    });

                    try {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) throw Exception('Nepřihlášený uživatel');

                      final updates = <String, dynamic>{
                        'daily_steps_goal': tempGoal,
                        'updated_at': FieldValue.serverTimestamp(),
                      };

                      final usernameChanged = enteredUsername != _username;
                      if (usernameChanged) {
                        if (!inGracePeriod) {
                          updates['last_username_change'] = FieldValue.serverTimestamp();
                          updates['username_grace_period_end'] = Timestamp.fromDate(
                            DateTime.now().add(const Duration(minutes: 10)),
                          );
                        }
                        updates['username'] = enteredUsername;
                        updates['username_clean'] = _cleanStringForSearch(enteredUsername);
                        
                        final friendCode = '#${enteredUsername.toUpperCase()}${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
                        updates['friend_code'] = friendCode;
                        updates['friend_code_clean'] = _cleanStringForSearch(friendCode);
                      }

                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update(updates);

                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('daily_steps_goal', tempGoal);
                      if (usernameChanged) {
                        const storage = FlutterSecureStorage();
                        await storage.write(key: 'user_name', value: enteredUsername);
                      }

                      await StepTrackerService().setStepsGoal(tempGoal);
                      await _loadProfileFromFirestore();

                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil byl úspěšně upraven.')),
                      );
                    } catch (e) {
                      setDialogState(() {
                        isSaving = false;
                        errorText = 'Chyba: ${e.toString()}';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lime,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Uložit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepsGoalCalendar() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    return Card(
      elevation: 0,
      color: const Color(0xFF1E272C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white12, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 Kalendář plnění kroků',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  'Série: 🔥 $_stepsStreak dnů',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFBFFF00)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: 28,
              itemBuilder: (context, index) {
                final dayDate = DateTime.now().subtract(Duration(days: 27 - index));
                final dateStr = dayDate.toIso8601String().substring(0, 10);
                final isAchieved = _stepsGoalHistory.contains(dateStr);
                final isToday = dateStr == todayStr;

                Color color = Colors.white10;
                if (isAchieved) {
                  color = const Color(0xFF1B5E20); // Pine Green
                } else if (isToday) {
                  color = const Color(0xFFBFFF00).withOpacity(0.25);
                }

                return GestureDetector(
                  onTap: () {
                    SharedPreferences.getInstance().then((prefs) {
                      final steps = prefs.getInt('daily_steps_$dateStr') ?? (isToday ? (prefs.getInt('pedometer_today_steps') ?? 0) : 0);
                      final gpsDistance = prefs.getDouble('daily_distance_$dateStr') ?? 0.0;
                      final stepDistance = steps * 0.00075;
                      final displayDistance = gpsDistance > stepDistance ? gpsDistance : stepDistance;

                      final dailyAchievements = prefs.getStringList('daily_achievements_$dateStr') ?? [];

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: const Color(0xFF1E1E24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(
                            '${dayDate.day}. ${dayDate.month}. ${dayDate.year}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isAchieved
                                      ? Colors.lime.shade800.withOpacity(0.3)
                                      : isToday
                                          ? Colors.lightBlue.shade800.withOpacity(0.3)
                                          : Colors.grey.shade800.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isAchieved
                                        ? Colors.lime
                                        : isToday
                                            ? Colors.lightBlue
                                            : Colors.grey,
                                  ),
                                ),
                                child: Text(
                                  isAchieved
                                      ? 'Cíl splněn! 🎉'
                                      : isToday
                                          ? 'Dnes se snažíš! 🏃‍♂️'
                                          : 'Cíl nesplněn 💤',
                                  style: TextStyle(
                                    color: isAchieved
                                        ? Colors.limeAccent
                                        : isToday
                                            ? Colors.lightBlueAccent
                                            : Colors.grey.shade400,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.directions_walk, color: Colors.lightBlueAccent),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Kroky: ',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    steps.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} "),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.linear_scale, color: Colors.limeAccent),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Vzdálenost: ',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  Text(
                                    '${displayDistance.toStringAsFixed(2)} km',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Získané odznaky:',
                                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              if (dailyAchievements.isEmpty)
                                const Text(
                                  'Žádné odznaky ten den',
                                  style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                                )
                              else
                                ...dailyAchievements.map((ach) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ach,
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Zavřít', style: TextStyle(color: Colors.cyanAccent)),
                            ),
                          ],
                        ),
                      );
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                      border: isToday ? Border.all(color: const Color(0xFFBFFF00), width: 1.5) : null,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Méně  ', style: TextStyle(fontSize: 11, color: Colors.white38)),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFFBFFF00).withOpacity(0.25), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 4),
                Container(width: 12, height: 12, decoration: BoxDecoration(color: const Color(0xFF1B5E20), borderRadius: BorderRadius.circular(3))),
                const Text('  Více', style: TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ),
          ],
        ),
      ),
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
    achievementItems.add({
      'title': 'Amulet',
      'unlocked': _storyAmuletCompleted,
      'type': 'story',
      'value': 99999.0,
      'icon': Icons.auto_stories,
    });
    achievementItems.add({
      'title': 'Lehká trasa',
      'unlocked': _storyDifficultyEasy,
      'type': 'story_difficulty',
      'value': 99998.0,
      'icon': Icons.explore,
    });
    achievementItems.add({
      'title': 'Střední trasa',
      'unlocked': _storyDifficultyMedium,
      'type': 'story_difficulty',
      'value': 99997.0,
      'icon': Icons.explore,
    });
    achievementItems.add({
      'title': 'Těžká trasa',
      'unlocked': _storyDifficultyHard,
      'type': 'story_difficulty',
      'value': 99996.0,
      'icon': Icons.explore,
    });
    achievementItems.add({
      'title': 'Hardcore trasa',
      'unlocked': _storyDifficultyHardcore,
      'type': 'story_difficulty',
      'value': 99995.0,
      'icon': Icons.explore,
    });

    final visibleAchievements = List<Map<String, dynamic>>.from(achievementItems)
      ..sort((a, b) {
        final unlockedA = a['unlocked'] as bool ? 0 : 1;
        final unlockedB = b['unlocked'] as bool ? 0 : 1;
        if (unlockedA != unlockedB) return unlockedA - unlockedB;
        return (b['value'] as double).compareTo(a['value'] as double);
      });

    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E272C),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            tooltip: 'Upravit profil',
            onPressed: _showEditProfileDialog,
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined, color: Colors.white70),
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _changeAvatar,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: const Color(0xFF1E272C),
                        child: Container(
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
                          child: ClipOval(
                            child: _selectedAvatar != null
                                ? (_selectedAvatar!.startsWith('base64:')
                                    ? Image.memory(
                                        base64Decode(_selectedAvatar!.substring(7)),
                                        fit: BoxFit.cover,
                                        width: 130,
                                        height: 130,
                                      )
                                    : Image.asset(
                                        'assets/images/$_selectedAvatar.png',
                                        fit: BoxFit.cover,
                                        width: 130,
                                        height: 130,
                                      ))
                                : const Icon(
                                    Icons.person,
                                    size: 100,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFBFFF00),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1B5E20)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _streakLabel(streak),
                  style: const TextStyle(
                    color: Color(0xFFBFFF00),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Limetky / Streak Card
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E272C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LIMETKY 🍋',
                                  style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$limetkyBalance',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'SÉRIE 🔥',
                                  style: TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$streak dnů',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isStreakFrozen) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Colors.white10),
                          const SizedBox(height: 12),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.ac_unit_rounded, color: Colors.blueAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Streak je momentálně zmrazený', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildStepsGoalCalendar(),
                const SizedBox(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Úspěchy',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
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
                
                // Show all achievements button
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFBFFF00).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFD4FF00),
                          Color(0xFFBFFF00),
                        ],
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AchievementsScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Zobrazit všechny úspěchy',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Log out button
                Padding(
                  padding: const EdgeInsets.only(bottom: 85.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _logout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade800,
                        side: BorderSide(color: Colors.red.shade100, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.red.shade50.withOpacity(0.5),
                      ),
                      child: const Text(
                        'Odhlásit se',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'v1.2.3+91',
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
    return GestureDetector(
      onTap: () {
        if (isUnlocked) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('🏆 Úspěch odemčen!', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 60, color: Colors.lime.shade700),
                    const SizedBox(height: 16),
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('Skvělá práce! Tento odznak jsi již úspěšně získal.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Zavřít', style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Sdílet'),
                    onPressed: () {
                      Navigator.pop(context);
                      Share.share('Odemkl jsem úspěch "$title" v mobilní aplikaci Hejbej se! 🏃‍♂️🏆 Pokoř mě také!');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lime,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              );
            },
          );
        } else {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tento úspěch je zatím uzamčen. Pokračuj v pohybu! 💪'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isUnlocked ? const Color(0xFFBFFF00).withOpacity(0.4) : Colors.white12,
            width: 1.5,
          ),
        ),
        color: isUnlocked ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFF1E272C),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: isUnlocked ? const Color(0xFFBFFF00) : Colors.white30,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked ? Colors.white : Colors.white30,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
