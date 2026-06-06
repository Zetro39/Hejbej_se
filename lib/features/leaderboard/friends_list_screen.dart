import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'add_friends_screen.dart';
import 'friend_profile_screen.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Keep track of when friends were last nudged
  Map<String, DateTime> _nudgeTimes = {};
  Timer? _nudgeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNudgeTimes();
    // Refresh the UI periodically to count down seconds/minutes
    _nudgeRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nudgeRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNudgeTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final Map<String, DateTime> loadedTimes = {};
      final now = DateTime.now();

      for (final key in keys) {
        if (key.startsWith('last_nudge_')) {
          final friendUid = key.substring('last_nudge_'.length);
          final timestamp = prefs.getInt(key);
          if (timestamp != null) {
            final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
            // Only keep it if it's within the last hour (3600 seconds)
            if (now.difference(dateTime).inHours < 1) {
              loadedTimes[friendUid] = dateTime;
            } else {
              await prefs.remove(key);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _nudgeTimes = loadedTimes;
        });
      }
    } catch (e) {
      debugPrint('Error loading nudge times: $e');
    }
  }

  bool _isNudgeLocked(String friendUid) {
    final lastNudge = _nudgeTimes[friendUid];
    if (lastNudge == null) return false;
    final now = DateTime.now();
    return now.difference(lastNudge).inHours < 1;
  }

  String _getRemainingNudgeTimeText(String friendUid) {
    final lastNudge = _nudgeTimes[friendUid];
    if (lastNudge == null) return '';
    final now = DateTime.now();
    final diff = now.difference(lastNudge);
    final remainingSeconds = 3600 - diff.inSeconds;
    if (remainingSeconds <= 0) return '';
    
    if (remainingSeconds < 60) {
      return '$remainingSeconds s';
    } else {
      final minutes = remainingSeconds ~/ 60;
      return '$minutes min';
    }
  }

  Future<void> _nudgeFriend(String friendUid, String friendName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final selectedMsg = await showDialog<String>(
      context: context,
      builder: (context) {
        final options = [
          'Zvedej se z gauče, lenochu! 🛋️🏃‍♂️',
          'Už ti dýchám na záda! 💨',
          'Dneska spíš? Koukej hejbnout zadkem! 😜',
        ];
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('💬 Vtipné popíchnutí', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              return Card(
                elevation: 1,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(opt, style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () => Navigator.pop(context, opt),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
            ),
          ],
        );
      },
    );

    if (selectedMsg == null) return;

    final now = DateTime.now();

    try {
      // 1. Fetch current user's username
      final myDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final myUsername = myDoc.data()?['username'] as String? ?? 'Uživatel';

      // 2. Write nudge to the activities collection targeting the friend's feed
      await _firestore.collection('activities').add({
        'uid': friendUid, // target friend's uid so it shows in their feed
        'username': friendName,
        'type': 'nudge',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'message': 'Uživatel $myUsername tě popíchnul: "$selectedMsg"',
          'senderName': myUsername,
          'senderUid': currentUser.uid,
        },
      });

      // Save lock time in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_nudge_$friendUid', now.millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _nudgeTimes[friendUid] = now;
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Popíchl jsi uživatele $friendName: "$selectedMsg"'),
          backgroundColor: Colors.lime.shade800,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nepodařilo se popíchnout kamaráda: $e')),
        );
      }
    }
  }


  Future<void> _removeRelationship(String targetUid, String targetName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Odebrat z přátel?'),
        content: Text('Opravdu chcete odebrat uživatele $targetName ze svých přátel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Odebrat'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final batch = _firestore.batch();

      final ref1 = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetUid);
      batch.delete(ref1);

      final ref2 = _firestore
          .collection('users')
          .doc(targetUid)
          .collection('friends')
          .doc(currentUser.uid);
      batch.delete(ref2);

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uživatel $targetName byl odebrán z přátel.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při rušení přátelství: $e')),
        );
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _getFriendsListStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .where('status', isEqualTo: 'friends')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'MOJI PŘÁTELÉ',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Přidat přátele',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getFriendsListStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends = snapshot.data ?? [];

            if (friends.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.lightBlue.shade50,
                      child: Icon(Icons.people_outline, size: 50, color: Colors.lightBlue.shade300),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Zatím tu nikdo není',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Přidej si své kamarády pomocí jejich kódu nebo QR kódu, abys mohl sledovat jejich pokroky a popichovat je k pohybu!',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddFriendsScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Přidat prvního přítele', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.lime,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: friends.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 70, color: Colors.black12),
              itemBuilder: (context, index) {
                final friend = friends[index];
                final uid = friend['uid'] as String? ?? '';
                final username = friend['username'] as String? ?? 'Uživatel';
                final code = friend['friend_code'] as String? ?? '';
                final isLocked = _isNudgeLocked(uid);
                final remainingTime = _getRemainingNudgeTimeText(uid);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FriendProfileScreen(friendUid: uid),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.lightBlue.shade100,
                          foregroundColor: Colors.black87,
                          child: Text(username.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              ),
                              if (code.isNotEmpty)
                                Text(
                                  code,
                                  style: const TextStyle(fontSize: 13, color: Colors.black45),
                                ),
                              if (isLocked && remainingTime.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    'Popíchnuto (znovu za $remainingTime)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Action: Nudge (Popíchnout)
                        IconButton(
                          icon: Icon(
                            isLocked ? Icons.timer_outlined : Icons.notifications_active,
                            color: isLocked ? Colors.grey : Colors.orangeAccent,
                          ),
                          tooltip: isLocked ? 'Popíchnutí uzamčeno' : 'Popíchnout k pohybu',
                          onPressed: isLocked ? null : () => _nudgeFriend(uid, username),
                        ),
                        // Action: Remove (Odebrat)
                        IconButton(
                          icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                          tooltip: 'Odebrat z přátel',
                          onPressed: () => _removeRelationship(uid, username),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
