import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int? _userAge;

  @override
  void initState() {
    super.initState();
    _loadUserAge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showWidgetPromoIfNeeded();
    });
  }

  Future<void> _loadUserAge() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _userAge = doc.data()?['age'] as int?;
        });
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

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HRY & VÝZVY'),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: currentUser == null
            ? const Center(child: Text('Uživatel není přihlášen'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Steps Card (from template)
                    _buildStepsCard(),
                    const SizedBox(height: 24),

                    // Special Games (e.g. Tour de Bear 18+)
                    _buildSpecialGamesSection(),

                    // Friend Activity Feed
                    _buildFriendActivityFeed(currentUser.uid),
                    
                    // 1v1 Challenges Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '1v1 Výzvy na míru',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateChallengeDialog(context),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nová výzva'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lime,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Challenges List
                    StreamBuilder<QuerySnapshot>(
                      stream: _firestore
                          .collection('challenges')
                          .where('participants', arrayContains: currentUser.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: CircularProgressIndicator(),
                          ));
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.lightBlue.shade50.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.lightBlue.shade100),
                            ),
                            child: Column(
                              children: const [
                                Icon(Icons.bolt, size: 48, color: Colors.lightBlue),
                                SizedBox(height: 12),
                                Text(
                                  'Zatím nemáš žádné výzvy.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Klikni na „Nová výzva“ a vyzvi přítele na souboj!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }

                        // Split challenges
                        final active = docs.where((doc) => doc['status'] == 'active').toList();
                        final pending = docs.where((doc) => doc['status'] == 'pending').toList();
                        final completed = docs.where((doc) => doc['status'] == 'completed').toList();

                        List<Widget> challengeWidgets = [];

                        if (active.isNotEmpty) {
                          challengeWidgets.add(_buildSectionTitle('Aktivní výzvy'));
                          challengeWidgets.addAll(active.map((doc) => _buildChallengeCard(doc, currentUser.uid)));
                        }

                        if (pending.isNotEmpty) {
                          challengeWidgets.add(_buildSectionTitle('Čekající žádosti'));
                          challengeWidgets.addAll(pending.map((doc) => _buildChallengeCard(doc, currentUser.uid)));
                        }

                        if (completed.isNotEmpty) {
                          challengeWidgets.add(_buildSectionTitle('Dokončené výzvy'));
                          challengeWidgets.addAll(completed.map((doc) => _buildChallengeCard(doc, currentUser.uid)));
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: challengeWidgets,
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
      ),
    );
  }

  Widget _buildStepsCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.lightBlue.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kroků dnes',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.lightBlue.shade700,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '0',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.lightBlue,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cíl: 10 000 kroků',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: LinearProgressIndicator(
                value: 0.0,
                minHeight: 12,
                backgroundColor: Colors.lightBlue.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lime),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard(QueryDocumentSnapshot doc, String currentUid) {
    final data = doc.data() as Map<String, dynamic>;
    final creatorUid = data['creatorUid'] as String;
    final opponentUid = data['opponentUid'] as String;
    final creatorUsername = data['creatorUsername'] as String;
    final opponentUsername = data['opponentUsername'] as String;
    final targetKm = (data['targetKm'] as num).toDouble();
    final durationDays = data['durationDays'] as int;
    final status = data['status'] as String;

    final isCreator = creatorUid == currentUid;
    final otherPlayerName = isCreator ? opponentUsername : creatorUsername;

    if (status == 'pending') {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Cíl: $targetKm km  |  Trvání: $durationDays dní', style: const TextStyle(color: Colors.black54)),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                      
                      // Progress Player 1 (You)
                      Text('Ty (progres)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: myProgress / targetKm,
                                minHeight: 12,
                                backgroundColor: Colors.lightBlue.shade50,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lime),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${myProgress.toStringAsFixed(1)} / $targetKm km', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress Player 2 (Opponent)
                      Text(otherPlayerName, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: opponentProgVal / targetKm,
                                minHeight: 12,
                                backgroundColor: Colors.grey.shade100,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.lightBlue),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${opponentProgVal.toStringAsFixed(1)} / $targetKm km', style: const TextStyle(fontSize: 12)),
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
        color: Colors.grey.shade50,
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
                        color: isWinner ? Colors.green.shade800 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cíl: $targetKm km',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () => _firestore.collection('challenges').doc(doc.id).delete(),
              )
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

    Map<String, dynamic>? selectedFriend = friends.first;
    double selectedKm = 10.0;
    int selectedDays = 7;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                  
                  // Friend Picker (Task 5)
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
                        value: selectedFriend,
                        items: friends.map((f) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: f,
                            child: Text(f['username'] as String),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setModalState(() {
                            selectedFriend = val;
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
                      final isSelected = selectedKm == km;
                      return ChoiceChip(
                        label: Text('${km.toInt()} km'),
                        selected: isSelected,
                        onSelected: (_) {
                          setModalState(() {
                            selectedKm = km;
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
                      final isSelected = selectedDays == days;
                      return ChoiceChip(
                        label: Text('$days ${days == 1 ? 'den' : days < 5 ? 'dny' : 'dní'}'),
                        selected: isSelected,
                        onSelected: (_) {
                          setModalState(() {
                            selectedDays = days;
                          });
                        },
                        selectedColor: Colors.lime,
                        backgroundColor: Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedFriend == null) return;
                      
                      try {
                        final currentDoc = await _firestore.collection('users').doc(currentUser.uid).get();
                        final currentUsername = currentDoc.data()?['username'] as String? ?? 'Uživatel';

                        await _firestore.collection('challenges').add({
                          'creatorUid': currentUser.uid,
                          'creatorUsername': currentUsername,
                          'opponentUid': selectedFriend!['uid'],
                          'opponentUsername': selectedFriend!['username'],
                          'participants': [currentUser.uid, selectedFriend!['uid']],
                          'targetKm': selectedKm,
                          'durationDays': selectedDays,
                          'status': 'pending',
                          'createdAt': FieldValue.serverTimestamp(),
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
          },
        );
      },
    );
  }

  Widget _buildSpecialGamesSection() {
    final show18Plus = _userAge != null && _userAge! >= 18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Speciální výpravy & hry',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 145,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildSpecialGameCard(
                title: 'Zámecká stezka',
                description: 'Objev historické zámky a parky ve svém okolí.',
                icon: Icons.fort,
                color: Colors.amber.shade50,
                iconColor: Colors.amber.shade700,
                is18Plus: false,
              ),
              const SizedBox(width: 12),
              _buildSpecialGameCard(
                title: 'Krakonošův okruh',
                description: 'Náročný výšlap horskou přírodou za bájným pánem hor.',
                icon: Icons.landscape,
                color: Colors.green.shade50,
                iconColor: Colors.green.shade700,
                is18Plus: false,
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
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSpecialGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required bool is18Plus,
  }) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: iconColor, size: 28),
              if (is18Plus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '18+',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
