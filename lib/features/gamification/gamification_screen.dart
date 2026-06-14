import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../../services/auth_service.dart';
import '../../services/step_tracker_service.dart';
import '../story_game/screens/story_map_screen.dart';
import 'models/wheel_of_fortune_model.dart';
import 'services/wheel_of_fortune_service.dart';
import 'wheel_editor_screen.dart';
import '../../main_shell.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int? _userAge;
  String? _selectedAvatar;
  String? _selectedCompanion;
  late ConfettiController _confettiController;
  bool _showCommunityWheels = false;
  final TextEditingController _searchCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    StepTrackerService().initialize();
    StepTrackerService().goalCompletedToday.addListener(_onGoalCompletedChange);
    _loadUserAge();
    _loadSelectedAvatar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWidgetPromoIfNeeded();
    });
  }

  void _onGoalCompletedChange() {
    if (StepTrackerService().goalCompletedToday.value) {
      _confettiController.play();
    }
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _selectedAvatar = prefs.getString('selected_avatar');
        _selectedCompanion = prefs.getString('selected_companion');
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _searchCodeController.dispose();
    StepTrackerService().goalCompletedToday.removeListener(_onGoalCompletedChange);
    super.dispose();
  }

  Future<void> _loadUserAge() async {
    // 1. Try loading and calculating from local SharedPreferences for instant offline display
    try {
      final prefs = await SharedPreferences.getInstance();
      final birthDateStr = prefs.getString('birth_date');
      if (birthDateStr != null) {
        final birthDate = DateTime.tryParse(birthDateStr);
        if (birthDate != null && mounted) {
          final today = DateTime.now();
          int age = today.year - birthDate.year;
          if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
            age--;
          }
          setState(() {
            _userAge = age;
          });
        }
      }
    } catch (_) {}

    // 2. Fetch and synchronize from Firestore
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final dbAge = doc.data()?['age'] as int?;
        if (dbAge != null) {
          setState(() {
            _userAge = dbAge;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _showWidgetPromoIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('widget_setup_prompt_shown') ?? false;
    if (shown) return;

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const Icon(Icons.widgets_outlined, color: Colors.lime, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Přidej si widget na plochu!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sleduj své denní kroky, vzdálenost a streak přímo z domovské obrazovky svého telefonu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Mock Widget Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.lime.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.lime, width: 2),
              ),
              child: Row(
                children: [
                  const Text('🏃', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Hejbej se!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Dnes: 1.2 km', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text('Streak: 🔥 5 dnů', style: TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Jak na to?\n1. Dlouze podrž plochu telefonu.\n2. Klikni na symbol + nebo Widgety.\n3. Vyhledej „Hejbej se“ a přidej widget na plochu.',
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Připomenout později', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setBool('widget_setup_prompt_shown', true);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Rozumím, zkusím to', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Stream<List<String>> _getFriendsUidsStream(String currentUid) {
    return _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'nyní';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return 'před chvílí';
    } else if (diff.inMinutes < 60) {
      return 'před ${diff.inMinutes} ${diff.inMinutes == 1 ? 'minutou' : diff.inMinutes < 5 ? 'minutami' : 'minutami'}';
    } else if (diff.inHours < 24) {
      return 'před ${diff.inHours} ${diff.inHours == 1 ? 'hodinou' : diff.inHours < 5 ? 'hodinami' : 'hodinami'}';
    } else if (diff.inDays < 7) {
      return 'před ${diff.inDays} ${diff.inDays == 1 ? 'dnem' : diff.inDays < 5 ? 'dny' : 'dny'}';
    } else {
      return '${date.day}. ${date.month}.';
    }
  }

  Widget _buildFriendActivityFeed(String currentUid) {
    return StreamBuilder<List<String>>(
      stream: _getFriendsUidsStream(currentUid),
      builder: (context, friendsSnap) {
        if (!friendsSnap.hasData) {
          return const SizedBox.shrink();
        }

        final friendUids = friendsSnap.data ?? [];
        final uidsForQuery = [currentUid, ...friendUids];
        final queryUids = uidsForQuery.take(30).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('activities')
              .where('uid', whereIn: queryUids)
              .orderBy('timestamp', descending: true)
              .limit(8)
              .snapshots(),
          builder: (context, activitySnap) {
            if (activitySnap.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Aktivity přátel se načítají... (Vytváří se databázový index)',
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              );
            }

            if (!activitySnap.hasData) {
              return const SizedBox.shrink();
            }

            final docs = activitySnap.data?.docs ?? [];

            if (docs.isEmpty) {
              return const SizedBox.shrink();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: const [
                    Icon(Icons.rss_feed, color: Colors.lightBlue),
                    SizedBox(width: 8),
                    Text(
                      'Aktivita přátel',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final username = data['username'] as String? ?? 'Uživatel';
                    final type = data['type'] as String? ?? '';
                    final timestamp = data['timestamp'] as Timestamp?;
                    final details = data['details'] as Map<String, dynamic>? ?? {};

                    IconData icon;
                    Color iconColor;
                    Widget content;

                    if (type == 'walk') {
                      final dist = (details['distance'] as num?)?.toDouble() ?? 0.0;
                      icon = Icons.directions_walk;
                      iconColor = Colors.lightBlue;
                      content = RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' ušel/ušla '),
                            TextSpan(text: '${dist.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.lightBlue)),
                            const TextSpan(text: '!'),
                          ],
                        ),
                      );
                    } else if (type == 'challenge_completed') {
                      final opponentName = details['opponentName'] as String? ?? 'kamarádem';
                      final winnerUid = details['winnerUid'] as String?;
                      final targetKm = (details['targetKm'] as num?)?.toDouble() ?? 0.0;
                      final isDraw = winnerUid == 'draw';

                      icon = Icons.emoji_events;
                      iconColor = Colors.orange;

                      if (isDraw) {
                        content = RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' remizoval/a v souboji na '),
                              TextSpan(text: '${targetKm.toInt()} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' s uživatelem '),
                              TextSpan(text: opponentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: '.'),
                            ],
                          ),
                        );
                      } else {
                        content = RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' vyhrál/a 1v1 výzvu na '),
                              TextSpan(text: '${targetKm.toInt()} km', style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' proti '),
                              TextSpan(text: opponentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: '! 🏆'),
                            ],
                          ),
                        );
                      }
                    } else if (type == 'friend_added') {
                      final friendName = details['friendName'] as String? ?? 'uživatelem';
                      icon = Icons.person_add;
                      iconColor = Colors.green;
                      content = RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' se propojil/a a spřátelil/a s uživatelem '),
                            TextSpan(text: friendName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      );
                    } else if (type == 'nudge') {
                      final message = details['message'] as String? ?? 'Tě popíchl k pohybu!';
                      icon = Icons.notifications_active;
                      iconColor = Colors.orange;
                      content = RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: message),
                          ],
                        ),
                      );
                    } else if (type == 'story_completion') {
                      final storyName = details['storyName'] as String? ?? 'Ztracený amulet';
                      icon = Icons.auto_stories;
                      iconColor = Colors.deepPurple;
                      content = RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: username, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const TextSpan(text: ' dokončil/a příběhovou linku '),
                            TextSpan(
                              text: storyName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                            ),
                            const TextSpan(text: '! 🧭✨'),
                          ],
                        ),
                      );
                    } else {
                      return const SizedBox.shrink();
                    }

                    return Card(
                      color: Colors.grey.shade50,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade100),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: iconColor.withOpacity(0.1),
                              foregroundColor: iconColor,
                              radius: 20,
                              child: Icon(icon, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  content,
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRelativeTime(timestamp),
                                    style: const TextStyle(color: Colors.black38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildChallengesTab(User? currentUser, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    if (currentUser == null) return const Center(child: Text('Uživatel není přihlášen'));
    return Stack(
      children: [
        // Background soft glowing gradients
        Positioned(
          top: 100,
          right: -80,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFBFFF00).withOpacity(0.06),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8F5E9).withOpacity(0.4),
            ),
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Denní aktivita 🏃',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildStepsCard(cardColor, textColor, textSecondary, borderColor),
              const SizedBox(height: 24),

              Text(
                'Speciální výpravy & Hry 🗺️',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              _buildSpecialGamesSectionBody(cardColor, textColor, textSecondary, borderColor),
              const SizedBox(height: 24),

              // 1v1 Challenges Card
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: cardColor,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                '1v1 Výzvy na míru',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateChallengeDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 18, color: Color(0xFF1B5E20)),
                            label: const Text('Nová', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFFF00),
                              shadowColor: const Color(0xFFBFFF00).withOpacity(0.3),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildChallengesList(currentUser.uid, cardColor, textColor, textSecondary, borderColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple, Colors.lime],
          ),
        ),
      ],
    );
  }

  Widget _buildChallengesList(String userId, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('challenges')
          .where('participants', arrayContains: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Zatím nemáš žádné výzvy. Klikni na „Nová výzva“!',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary),
              ),
            ),
          );
        }

        final active = docs.where((doc) => doc['status'] == 'active').toList();
        final pending = docs.where((doc) => doc['status'] == 'pending').toList();
        final completed = docs.where((doc) => doc['status'] == 'completed').toList();

        List<Widget> challengeWidgets = [];

        if (active.isNotEmpty) {
          challengeWidgets.add(_buildSectionTitle('Aktivní výzvy', textColor));
          challengeWidgets.addAll(active.map((doc) => _buildChallengeCard(doc, userId, cardColor, textColor, textSecondary, borderColor)));
        }

        if (pending.isNotEmpty) {
          challengeWidgets.add(_buildSectionTitle('Čekající žádosti', textColor));
          challengeWidgets.addAll(pending.map((doc) => _buildChallengeCard(doc, userId, cardColor, textColor, textSecondary, borderColor)));
        }

        if (completed.isNotEmpty) {
          challengeWidgets.add(_buildSectionTitle('Dokončené výzvy', textColor));
          challengeWidgets.addAll(completed.map((doc) => _buildChallengeCard(doc, userId, cardColor, textColor, textSecondary, borderColor)));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: challengeWidgets,
        );
      },
    );
  }

  Widget _buildSpecialGamesSectionBody(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    final show18Plus = _userAge != null && _userAge! >= 18;
    return SizedBox(
      height: 145,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildSpecialGameCard(
            title: 'Ztracený amulet 💎',
            description: 'Příběhové RPG. Ujdi 6 km a vyřeš záhadu ztraceného amuletu.',
            icon: Icons.auto_awesome,
            color: Colors.purple.shade50,
            iconColor: Colors.purple.shade700,
            is18Plus: false,
            cardColor: cardColor,
            textColor: textColor,
            textSecondary: textSecondary,
            borderColor: borderColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoryMapScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          _buildSpecialGameCard(
            title: 'Zámecká stezka',
            description: 'Objev historické zámky and parky ve svém okolí.',
            icon: Icons.fort,
            color: Colors.amber.shade50,
            iconColor: Colors.amber.shade700,
            is18Plus: false,
            cardColor: cardColor,
            textColor: textColor,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          const SizedBox(width: 12),
          _buildSpecialGameCard(
            title: 'Krakonošův okruh',
            description: 'Náročný výšlap horskou přírodou za bájným pánem hor.',
            icon: Icons.landscape,
            color: Colors.green.shade50,
            iconColor: Colors.green.shade700,
            is18Plus: false,
            cardColor: cardColor,
            textColor: textColor,
            textSecondary: textSecondary,
            borderColor: borderColor,
          ),
          if (show18Plus) ...[
            const SizedBox(width: 12),
            _buildSpecialGameCard(
              title: 'Tour de Bear (18+)',
              description: 'Chmelový okruh po lokálních hospůdkách a pivovarech.',
              icon: Icons.sports_bar,
              color: Colors.red.shade50,
              iconColor: Colors.red.shade700,
              is18Plus: true,
              cardColor: cardColor,
              textColor: textColor,
              textSecondary: textSecondary,
              borderColor: borderColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGameCreatorTab(User? currentUser, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    if (currentUser == null) return const Center(child: Text('Uživatel není přihlášen'));
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Stáhnout hru podle kódu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCodeController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Např. #K15746',
                            hintStyle: TextStyle(color: textSecondary),
                            prefixIcon: Icon(Icons.tag, color: textSecondary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            isDense: true,
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final code = _searchCodeController.text.trim();
                          if (code.isEmpty) return;
                          
                          final wheel = await WheelOfFortuneService().searchWheelByCode(code);
                          if (wheel != null) {
                            _searchCodeController.clear();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hra "${wheel.name}" byla úspěšně stažena!')),
                            );
                            setState(() {});
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Hra s tímto kódem nebyla nalezena.')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('STÁHNOUT', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WheelEditorScreen()),
              );
              if (result == true) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vlastní automat úspěšně vytvořen!')),
                );
              }
            },
            icon: const Icon(Icons.add_circle_outline, size: 24),
            label: const Text('VYTVOŘIT VLASTNÍ AUTOMAT ÚKOLŮ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.black, width: 2),
              ),
              elevation: 4,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: ExpansionTile(
              title: Text('Od HEJBEJ 🍋', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor)),
              leading: const Icon(Icons.verified, color: Colors.amber),
              collapsedIconColor: textSecondary,
              iconColor: textColor,
              initiallyExpanded: true,
              children: [
                Column(
                  children: WheelOfFortuneService().getOfficialWheels().map((wheel) {
                    return _buildWheelListTile(wheel, isOfficial: true, currentUser: currentUser, cardColor: cardColor, textColor: textColor, textSecondary: textSecondary, borderColor: borderColor);
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: ExpansionTile(
              title: Text('Od hráčů 👥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: textColor)),
              leading: const Icon(Icons.people, color: Colors.blue),
              collapsedIconColor: textSecondary,
              iconColor: textColor,
              children: [
                _buildPlayersWheelsSubTab(currentUser, cardColor, textColor, textSecondary, borderColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersWheelsSubTab(User currentUser, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  showCheckmark: false,
                  backgroundColor: cardColor,
                  label: Center(
                    child: Text(
                      'Moje a stažené',
                      style: TextStyle(color: !_showCommunityWheels ? Colors.black : textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: !_showCommunityWheels,
                  selectedColor: const Color(0xFFBFFF00),
                  onSelected: (val) {
                    setState(() => _showCommunityWheels = false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  showCheckmark: false,
                  backgroundColor: cardColor,
                  label: Center(
                    child: Text(
                      'Top z komunity',
                      style: TextStyle(color: _showCommunityWheels ? Colors.black : textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                  selected: _showCommunityWheels,
                  selectedColor: const Color(0xFFBFFF00),
                  onSelected: (val) {
                    setState(() => _showCommunityWheels = true);
                  },
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: borderColor),
        _showCommunityWheels
            ? _buildCommunityWheelsList(currentUser.uid, cardColor, textColor, textSecondary, borderColor)
            : _buildLocalWheelsList(currentUser, cardColor, textColor, textSecondary, borderColor),
      ],
    );
  }

  Widget _buildLocalWheelsList(User currentUser, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return FutureBuilder<List<WheelOfFortune>>(
      future: WheelOfFortuneService().getCustomWheels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ));
        }

        final wheels = snapshot.data ?? [];
        if (wheels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Nemáš stažené ani vytvořené žádné automaty úkolů.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
          );
        }

        return Column(
          children: wheels.map((w) => _buildWheelListTile(w, isOfficial: false, currentUser: currentUser, cardColor: cardColor, textColor: textColor, textSecondary: textSecondary, borderColor: borderColor)).toList(),
        );
      },
    );
  }

  Widget _buildCommunityWheelsList(String currentUserId, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return FutureBuilder<List<WheelOfFortune>>(
      future: WheelOfFortuneService().fetchTopRatedCommunityWheels(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ));
        }

        final wheels = snapshot.data ?? [];
        if (wheels.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'V komunitě zatím nejsou sdílené žádné automaty.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary),
            ),
          );
        }

        return Column(
          children: wheels.map((w) {
            return ListTile(
              title: Text(w.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              subtitle: Text('Autor: ${w.creatorName} • Kód: #${w.code}', style: TextStyle(color: textSecondary)),
              leading: const Icon(Icons.public, color: Colors.green),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.blue),
                    onPressed: () async {
                      await WheelOfFortuneService().likeCommunityWheel(w.id, currentUserId);
                      setState(() {});
                    },
                  ),
                  Text('${w.likes}', style: TextStyle(color: textColor)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.download_for_offline_outlined, color: Colors.lightBlue),
                    onPressed: () async {
                      await WheelOfFortuneService().saveCustomWheel(w);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hra "${w.name}" stažena mezi tvé lokální hry!')),
                      );
                      setState(() {});
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildWheelListTile(WheelOfFortune w, {
    required bool isOfficial,
    required User currentUser,
    required Color cardColor,
    required Color textColor,
    required Color textSecondary,
    required Color borderColor,
  }) {
    return ListTile(
      title: Text(w.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
      subtitle: Text(
        isOfficial 
            ? 'Oficiální • ${w.tasks.length} úkolů' 
            : 'Kód: #${w.code.isNotEmpty ? w.code : "Není sdíleno"} • ${w.tasks.length} úkolů',
        style: TextStyle(color: textSecondary),
      ),
      leading: Icon(isOfficial ? Icons.verified : Icons.casino, color: isOfficial ? Colors.amber : Colors.blue),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.visibility_outlined, color: textSecondary),
            onPressed: () => _showWheelPreviewDialog(w),
          ),
          if (!isOfficial) ...[
            if (w.code.isEmpty)
              IconButton(
                icon: const Icon(Icons.share, color: Colors.blue),
                tooltip: 'Sdílet do komunity',
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Nahrávání a generování kódu...'),
                        ],
                      ),
                      duration: Duration(days: 1),
                    ),
                  );
                  try {
                    final code = await WheelOfFortuneService().shareWheelToCommunity(w, currentUser.uid, currentUser.displayName ?? 'Hráč');
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hra sdílena! Kód #$code byl zkopírován do schránky.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await Clipboard.setData(ClipboardData(text: '#$code'));
                    setState(() {});
                  } catch (e) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Chyba při sdílení: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.share, color: Colors.green),
                tooltip: 'Sdílet kód s přáteli',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: '#${w.code}'));
                  await Share.share(
                    'Ahoj! Přidej si moji hru "${w.name}" v aplikaci Hejbej se. Stačí zadat tento kód: #${w.code}',
                    subject: 'Moje hra v Hejbej se',
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Kód #${w.code} zkopírován do schránky a sdílen!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                await WheelOfFortuneService().deleteCustomWheel(w.id);
                setState(() {});
              },
            ),
          ],
        ],
      ),
    );
  }

  void _showWheelPreviewDialog(WheelOfFortune w) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: w.tasks.length,
            itemBuilder: (context, index) {
              final task = w.tasks[index];
              return ListTile(
                title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${task.description}\nVýjimky: ${task.exceptions}'),
                isThreeLine: true,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ZAVŘÍT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return ValueListenableBuilder<String>(
      valueListenable: MainShell.themeNotifier,
      builder: (context, theme, child) {
        final isWhite = theme == 'white';
        final bgColor = isWhite ? const Color(0xFFF9FBFC) : const Color(0xFF263238);
        final cardColor = isWhite ? Colors.white : const Color(0xFF1E272C);
        final textColor = isWhite ? const Color(0xFF263238) : Colors.white;
        final textSecondary = isWhite ? Colors.black54 : Colors.white70;
        final borderColor = isWhite ? Colors.grey.shade200 : Colors.white12;
        final appBarBg = isWhite ? Colors.white : const Color(0xFF1E272C);
        final appBarFg = isWhite ? const Color(0xFF263238) : Colors.white;

        return Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: bgColor,
            cardTheme: CardThemeData(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
            ),
            textTheme: Theme.of(context).textTheme.apply(
              bodyColor: textColor,
              displayColor: textColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: appBarBg,
              foregroundColor: appBarFg,
            ),
          ),
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: bgColor,
              appBar: AppBar(
                title: Text(
                  'Hry & Výzvy',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5, color: appBarFg),
                ),
                centerTitle: true,
                backgroundColor: appBarBg,
                foregroundColor: appBarFg,
                elevation: 0,
                bottom: TabBar(
                  indicatorColor: const Color(0xFFBFFF00),
                  labelColor: const Color(0xFFBFFF00),
                  unselectedLabelColor: appBarFg.withOpacity(0.6),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(icon: Icon(Icons.star_rounded), text: 'Výzvy'),
                    Tab(icon: Icon(Icons.casino_rounded), text: 'Tvorba her'),
                  ],
                ),
              ),
              body: SafeArea(
                child: currentUser == null
                    ? const Center(child: Text('Uživatel není přihlášen'))
                    : TabBarView(
                        children: [
                          _buildChallengesTab(currentUser, cardColor, textColor, textSecondary, borderColor),
                          _buildGameCreatorTab(currentUser, cardColor, textColor, textSecondary, borderColor),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
      ),
    );
  }

  Widget _buildStepsCard(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return ValueListenableBuilder<int>(
      valueListenable: StepTrackerService().stepsNotifier,
      builder: (context, steps, _) {
        return ValueListenableBuilder<int>(
          valueListenable: StepTrackerService().goalNotifier,
          builder: (context, goal, _) {
            final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;
            return Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'KROKŮ DNES',
                              style: TextStyle(
                                color: Color(0xFFBFFF00),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              steps.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} "),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 32,
                                color: textColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedCompanion != null)
                          MascotWidget(
                            avatar: _selectedCompanion!,
                            progress: progress,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cíl: ${goal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} ")} kroků',
                          style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '${(progress * 100).toInt()}% splněno',
                          style: const TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 12,
                        backgroundColor: cardColor == Colors.white ? Colors.grey.shade100 : Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFBFFF00)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChallengeCard(QueryDocumentSnapshot doc, String currentUid, Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    final data = doc.data() as Map<String, dynamic>;
    final creatorUid = data['creatorUid'] as String;
    final opponentUid = data['opponentUid'] as String;
    final creatorUsername = data['creatorUsername'] as String;
    final opponentUsername = data['opponentUsername'] as String;
    final targetKm = (data['targetKm'] as num).toDouble();
    final durationDays = data['durationDays'] as int;
    final status = data['status'] as String;
    final bet = data['bet'] as String? ?? '';

    final isCreator = creatorUid == currentUid;
    final otherPlayerName = isCreator ? opponentUsername : creatorUsername;

    if (status == 'pending') {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: cardColor,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isCreator
                          ? 'Vyzval jsi uživatele $otherPlayerName'
                          : 'Výzva od uživatele $otherPlayerName',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cíl: $targetKm km  |  Trvání: $durationDays dní', style: TextStyle(color: textSecondary)),
              if (bet.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wine_bar, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sázka: $bet',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (!isCreator)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _firestore.collection('challenges').doc(doc.id).delete(),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Odmítnout'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _acceptChallenge(doc.id, creatorUid, opponentUid, durationDays),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.lime, foregroundColor: Colors.black),
                      child: const Text('Přijmout'),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _firestore.collection('challenges').doc(doc.id).delete(),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Zrušit výzvu'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    if (status == 'active') {
      final endDate = (data['endDate'] as Timestamp).toDate();
      final remaining = endDate.difference(DateTime.now());
      final hoursLeft = remaining.inHours;

      return StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('users').doc(creatorUid).snapshots(),
        builder: (context, creatorSnap) {
          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('users').doc(opponentUid).snapshots(),
            builder: (context, opponentSnap) {
              if (!creatorSnap.hasData || !opponentSnap.hasData) {
                return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              }

              final creatorData = creatorSnap.data?.data() as Map<String, dynamic>? ?? {};
              final opponentData = opponentSnap.data?.data() as Map<String, dynamic>? ?? {};

              final creatorTotalDist = (creatorData['totalDistance'] as num?)?.toDouble() ?? 0.0;
              final opponentTotalDist = (opponentData['totalDistance'] as num?)?.toDouble() ?? 0.0;

              final creatorStart = (data['creatorStartDistance'] as num).toDouble();
              final opponentStart = (data['opponentStartDistance'] as num).toDouble();

              double creatorProgress = (creatorTotalDist - creatorStart).clamp(0.0, targetKm);
              double opponentProgress = (opponentTotalDist - opponentStart).clamp(0.0, targetKm);

              // Check for automatic completion inside build flow safely in background
              if (creatorProgress >= targetKm || opponentProgress >= targetKm || remaining.isNegative) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _completeChallenge(doc.id, creatorUid, opponentUid, creatorProgress, opponentProgress, targetKm);
                });
              }

              final myProgress = isCreator ? creatorProgress : opponentProgress;
              final opponentProgVal = isCreator ? opponentProgress : creatorProgress;

              final leadingText = myProgress > opponentProgVal
                  ? 'Ty vedeš o ${(myProgress - opponentProgVal).toStringAsFixed(1)} km! 🥳'
                  : myProgress < opponentProgVal
                      ? '$otherPlayerName vede o ${(opponentProgVal - myProgress).toStringAsFixed(1)} km! 😮'
                      : 'Máte remízu! 🤝';

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: cardColor,
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Souboj s $otherPlayerName',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                          ),
                          Text(
                            hoursLeft > 24
                                ? 'Zbývá ${remaining.inDays} dní'
                                : hoursLeft > 0
                                    ? 'Zbývá $hoursLeft hod'
                                    : 'Konec výzvy',
                            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (bet.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wine_bar, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sázka: $bet',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      // Progress Player 1 (You)
                      Text('Ty (progres)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: myProgress / targetKm,
                                minHeight: 12,
                                backgroundColor: cardColor == Colors.white ? Colors.grey.shade200 : Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lime),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${myProgress.toStringAsFixed(1)} / $targetKm km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Player 2 (Opponent)
                      Text(otherPlayerName, style: TextStyle(fontSize: 13, color: textSecondary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: opponentProgVal / targetKm,
                                minHeight: 12,
                                backgroundColor: cardColor == Colors.white ? Colors.grey.shade200 : Colors.white10,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${opponentProgVal.toStringAsFixed(1)} / $targetKm km', style: TextStyle(fontSize: 12, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Status Label
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          leadingText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.lightBlue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    if (status == 'completed') {
      final winnerUid = data['winnerUid'] as String?;
      final isWinner = winnerUid == currentUid;
      final isDraw = winnerUid == 'draw';

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1,
        color: cardColor,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(
                isDraw
                    ? '🤝'
                    : isWinner
                        ? '🥇'
                        : '🥈',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDraw
                        ? 'Remíza s $otherPlayerName'
                        : isWinner
                            ? 'Vyhrál jsi souboj s $otherPlayerName!'
                            : 'Prohrál jsi souboj s $otherPlayerName',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDraw 
                            ? textColor 
                            : isWinner 
                                ? (cardColor == Colors.white ? Colors.green.shade800 : Colors.green.shade400) 
                                : textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cíl: $targetKm km',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                    if (bet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        isDraw 
                            ? 'Sázka ($bet) propadla.'
                            : isWinner 
                                ? 'Vyhráváš sázku: $bet! 🍻' 
                                : 'Musíš splnit sázku: $bet 😢',
                        style: TextStyle(
                          fontSize: 12, 
                          color: isWinner ? Colors.orange.shade800 : Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _firestore.collection('challenges').doc(doc.id).delete(),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // Accept Challenge
  Future<void> _acceptChallenge(String challengeId, String creatorUid, String opponentUid, int durationDays) async {
    try {
      final creatorDoc = await _firestore.collection('users').doc(creatorUid).get();
      final opponentDoc = await _firestore.collection('users').doc(opponentUid).get();

      final creatorDist = (creatorDoc.data()?['totalDistance'] as num?)?.toDouble() ?? 0.0;
      final opponentDist = (opponentDoc.data()?['totalDistance'] as num?)?.toDouble() ?? 0.0;

      final start = DateTime.now();
      final end = start.add(Duration(days: durationDays));

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'active',
        'startDate': start,
        'endDate': end,
        'creatorStartDistance': creatorDist,
        'opponentStartDistance': opponentDist,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nepodařilo se přijmout výzvu: $e')));
    }
  }

  // Complete Challenge and set Winner
  Future<void> _completeChallenge(String challengeId, String creatorUid, String opponentUid, double creatorEnd, double opponentEnd, double targetKm) async {
    String winnerUid;
    if (creatorEnd >= targetKm && opponentEnd >= targetKm) {
      winnerUid = creatorEnd > opponentEnd ? creatorUid : opponentUid;
    } else if (creatorEnd >= targetKm) {
      winnerUid = creatorUid;
    } else if (opponentEnd >= targetKm) {
      winnerUid = opponentUid;
    } else {
      if (creatorEnd == opponentEnd) {
        winnerUid = 'draw';
      } else {
        winnerUid = creatorEnd > opponentEnd ? creatorUid : opponentUid;
      }
    }

    try {
      final challengeDoc = await _firestore.collection('challenges').doc(challengeId).get();
      final chalData = challengeDoc.data() ?? {};
      if (chalData['status'] == 'completed' || chalData['isActivityLogged'] == true) {
        return; // Already completed or logged
      }

      await _firestore.collection('challenges').doc(challengeId).update({
        'status': 'completed',
        'winnerUid': winnerUid,
        'isActivityLogged': true,
      });

      // Write to activities feed
      final creatorUsername = chalData['creatorUsername'] ?? 'Uživatel';
      final opponentUsername = chalData['opponentUsername'] ?? 'Uživatel';
      final winnerName = winnerUid == 'draw' 
          ? 'Remíza' 
          : (winnerUid == creatorUid ? creatorUsername : opponentUsername);

      await _firestore.collection('activities').add({
        'uid': winnerUid == 'draw' ? creatorUid : winnerUid,
        'username': winnerName,
        'type': 'challenge_completed',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'opponentName': winnerUid == creatorUid ? opponentUsername : creatorUsername,
          'creatorName': creatorUsername,
          'targetKm': targetKm,
          'winnerUid': winnerUid,
        },
      });
    } catch (_) {}
  }

  // Task 4, 5, 6: Dialog to create challenge
  Future<void> _showCreateChallengeDialog(BuildContext context) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Fetch user's friends list
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .get();

    final List<Map<String, dynamic>> friends = friendsSnapshot.docs.map((doc) => doc.data()).toList();

    if (friends.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nemáš žádné přátele'),
          content: const Text('Pro vytvoření 1v1 výzvy si nejprve přidej přítele na obrazovce Žebříčku.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Rozumím'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _CreateChallengeBottomSheet(
          currentUid: currentUser.uid,
          friends: friends,
          firestore: _firestore,
        );
      },
    );
  }


  Widget _buildSpecialGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required bool is18Plus,
    required Color cardColor,
    required Color textColor,
    required Color textSecondary,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                if (is18Plus)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      '18+',
                      style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: textSecondary, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateChallengeBottomSheet extends StatefulWidget {
  final String currentUid;
  final List<Map<String, dynamic>> friends;
  final FirebaseFirestore firestore;

  const _CreateChallengeBottomSheet({
    required this.currentUid,
    required this.friends,
    required this.firestore,
  });

  @override
  State<_CreateChallengeBottomSheet> createState() => _CreateChallengeBottomSheetState();
}

class _CreateChallengeBottomSheetState extends State<_CreateChallengeBottomSheet> {
  Map<String, dynamic>? _selectedFriend;
  double _selectedKm = 10.0;
  int _selectedDays = 7;
  final TextEditingController _betController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.friends.isNotEmpty) {
      _selectedFriend = widget.friends.first;
    }
  }

  @override
  void dispose() {
    _betController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Vytvořit 1v1 výzvu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Friend Picker
          const Text('Vyber přítele:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Map<String, dynamic>>(
                value: _selectedFriend,
                items: widget.friends.map((f) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: f,
                    child: Text(f['username'] as String),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedFriend = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Distance Target
          const Text('Cíl výzvy:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [5.0, 10.0, 20.0, 50.0].map((km) {
              final isSelected = _selectedKm == km;
              return ChoiceChip(
                label: Text('${km.toInt()} km'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedKm = km;
                  });
                },
                selectedColor: Colors.lime,
                backgroundColor: Colors.grey.shade100,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Duration Days
          const Text('Délka trvání:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [1, 3, 7, 14].map((days) {
              final isSelected = _selectedDays == days;
              return ChoiceChip(
                label: Text('$days ${days == 1 ? 'den' : days < 5 ? 'dny' : 'dní'}'),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _selectedDays = days;
                  });
                },
                selectedColor: Colors.lime,
                backgroundColor: Colors.grey.shade100,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Sázka input field
          const Text('O co se vsadíte? (Nepovinné):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _betController,
            decoration: InputDecoration(
              hintText: 'Např. pivo, čokoláda, mytí nádobí...',
              hintStyle: const TextStyle(color: Colors.black38),
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.wine_bar, color: Colors.orange),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Submit
          ElevatedButton(
            onPressed: () async {
              if (_selectedFriend == null) return;
              
              try {
                final currentDoc = await widget.firestore.collection('users').doc(widget.currentUid).get();
                final currentUsername = currentDoc.data()?['username'] as String? ?? 'Uživatel';

                await widget.firestore.collection('challenges').add({
                  'creatorUid': widget.currentUid,
                  'creatorUsername': currentUsername,
                  'opponentUid': _selectedFriend!['uid'],
                  'opponentUsername': _selectedFriend!['username'],
                  'participants': [widget.currentUid, _selectedFriend!['uid']],
                  'targetKm': _selectedKm,
                  'durationDays': _selectedDays,
                  'status': 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'bet': _betController.text.trim(),
                });
                
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Výzva byla odeslána.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nepodařilo se vytvořit výzvu: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Odeslat výzvu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

enum MascotState { sleeping, running, celebrating }

class MascotWidget extends StatefulWidget {
  final String avatar;
  final double progress;

  const MascotWidget({
    super.key,
    required this.avatar,
    required this.progress,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> with TickerProviderStateMixin {
  late AnimationController _idleController;
  late AnimationController _runController;
  late AnimationController _celebrateController;

  // For particles
  final List<_MascotParticle> _particles = [];
  late AnimationController _particleController;

  MascotState get _state {
    if (widget.progress >= 1.0) {
      return MascotState.celebrating;
    } else if (widget.progress >= 0.3) {
      return MascotState.running;
    } else {
      return MascotState.sleeping;
    }
  }

  @override
  void initState() {
    super.initState();
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _runController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateParticles);
    _particleController.repeat();

    _spawnParticleTimer();
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (int i = _particles.length - 1; i >= 0; i--) {
        final p = _particles[i];
        p.age += 0.02;
        p.y -= p.speedY;
        p.x += p.speedX;
        if (p.age >= 1.0) {
          _particles.removeAt(i);
        }
      }
    });
  }

  void _spawnParticleTimer() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) break;
      _spawnParticle();
    }
  }

  void _spawnParticle() {
    final state = _state;
    if (state == MascotState.sleeping) {
      _particles.add(_MascotParticle(
        text: 'Zzz',
        x: 35.0,
        y: 20.0,
        speedX: 0.3 + (0.4 * (0.5 - (0.01 * (DateTime.now().millisecond % 100)))),
        speedY: 0.8,
        color: Colors.lightBlue.shade300,
        fontSize: 12.0,
      ));
    } else if (state == MascotState.running) {
      _particles.add(_MascotParticle(
        text: '💨',
        x: -15.0,
        y: 50.0,
        speedX: -1.2,
        speedY: -0.2,
        fontSize: 16.0,
      ));
    } else if (state == MascotState.celebrating) {
      final emojis = ['🎉', '🥳', '🏆', '⭐', '✨'];
      final text = emojis[DateTime.now().millisecond % emojis.length];
      _particles.add(_MascotParticle(
        text: text,
        x: 10.0 + (DateTime.now().millisecond % 50),
        y: 10.0,
        speedX: -1.0 + (2.0 * ((DateTime.now().millisecond % 100) / 100)),
        speedY: 1.5,
        fontSize: 16.0,
      ));
    }
  }

  @override
  void dispose() {
    _idleController.dispose();
    _runController.dispose();
    _celebrateController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Widget _buildMascotImage() {
    final avatar = widget.avatar;
    String assetName = 'bear.png';

    // Preset mapping to mascot animals
    if (avatar == 'boy' || avatar == 'chlap' || avatar == 'bear') {
      assetName = 'bear.png';
    } else if (avatar == 'girl' || avatar == 'fox') {
      assetName = 'fox.png';
    } else if (avatar == 'woman' || avatar == 'deer') {
      assetName = 'deer.png';
    } else if (avatar == 'man' || avatar == 'wolf') {
      assetName = 'wolf.png';
    }

    if (avatar.startsWith('base64:')) {
      try {
        final bytes = base64Decode(avatar.substring(7));
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
          width: 80,
          height: 80,
        );
      } catch (_) {
        // fallback
      }
    }

    return Image.asset(
      'assets/images/$assetName',
      fit: BoxFit.contain,
      width: 80,
      height: 80,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget animatedMascot;
    final state = _state;

    if (state == MascotState.sleeping) {
      animatedMascot = ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.02).animate(
          CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
        ),
        child: Opacity(
          opacity: 0.9,
          child: _buildMascotImage(),
        ),
      );
    } else if (state == MascotState.running) {
      animatedMascot = AnimatedBuilder(
        animation: _runController,
        builder: (context, child) {
          final rotationValue = -0.06 + (0.06 - (-0.06)) * _runController.value;
          final bounceValue = 0.0 + (-8.0 - 0.0) * _runController.value;
          return Transform.translate(
            offset: Offset(0, bounceValue),
            child: Transform.rotate(
              angle: rotationValue,
              child: child,
            ),
          );
        },
        child: _buildMascotImage(),
      );
    } else {
      // celebrating
      animatedMascot = AnimatedBuilder(
        animation: _celebrateController,
        builder: (context, child) {
          final bounceValue = 0.0 + (-20.0 - 0.0) * _celebrateController.value;
          // squash and stretch effect
          double scaleY = 1.0;
          double scaleX = 1.0;
          if (_celebrateController.value < 0.2) {
            scaleY = 0.85 + (1.0 - 0.85) * (_celebrateController.value / 0.2);
            scaleX = 1.15 + (1.0 - 1.15) * (_celebrateController.value / 0.2);
          } else if (_celebrateController.value > 0.8) {
            scaleY = 1.0 + (0.85 - 1.0) * ((_celebrateController.value - 0.8) / 0.2);
            scaleX = 1.0 + (1.15 - 1.0) * ((_celebrateController.value - 0.8) / 0.2);
          }
          return Transform.translate(
            offset: Offset(0, bounceValue),
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              child: child,
            ),
          );
        },
        child: _buildMascotImage(),
      );
    }

    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Mascot Base / shadow
          Positioned(
            bottom: 15,
            child: Container(
              width: 65,
              height: 10,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: state == MascotState.sleeping ? 6 : 4,
                    spreadRadius: state == MascotState.sleeping ? 1 : -1,
                  ),
                ],
              ),
            ),
          ),
          
          // Emojis / Particle effects
          ..._particles.map((p) {
            return Positioned(
              left: 55 + p.x,
              top: 55 - p.y,
              child: Opacity(
                opacity: (1.0 - p.age).clamp(0.0, 1.0),
                child: Text(
                  p.text,
                  style: TextStyle(
                    fontSize: p.fontSize,
                    fontWeight: FontWeight.bold,
                    color: p.color,
                  ),
                ),
              ),
            );
          }),

          // Mascot animated image
          Positioned(
            bottom: 20,
            child: animatedMascot,
          ),
        ],
      ),
    );
  }
}

class _MascotParticle {
  final String text;
  double x;
  double y;
  final double speedX;
  final double speedY;
  final Color? color;
  final double fontSize;
  double age = 0.0;

  _MascotParticle({
    required this.text,
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    this.color,
    required this.fontSize,
  });
}
