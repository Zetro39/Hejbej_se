import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'add_friends_screen.dart';
import 'friend_profile_screen.dart';
import '../../main_shell.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Map<String, DateTime> _nudgeTimes = {};
  Timer? _nudgeRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNudgeTimes();
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

    final isWhite = MainShell.themeNotifier.value == 'white';
    final dialogBg = isWhite ? Colors.white : const Color(0xFF37474F);
    final cardColor = isWhite ? Colors.grey.shade100 : const Color(0xFF1E272C);
    final textColor = isWhite ? Colors.black : Colors.white;
    final textSecondary = isWhite ? Colors.black54 : Colors.white70;
    final borderColor = isWhite ? Colors.grey.shade300 : Colors.white10;

    final selectedMsg = await showDialog<String>(
      context: context,
      builder: (context) {
        final options = [
          'Zvedej se z gauče, lenochu! 🛋️🏃‍♂️',
          'Už ti dýchám na záda! 💨',
          'Dneska spíš? Koukej hejbnout zadkem! 😜',
          '✍️ Vlastní zpráva...',
        ];
        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: borderColor),
          ),
          title: Text(
            '💬 Vtipné popíchnutí',
            style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              return Card(
                color: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: borderColor),
                ),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(opt, style: TextStyle(fontSize: 14, color: textColor)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFBFFF00)),
                  onTap: () async {
                    if (opt == '✍️ Vlastní zpráva...') {
                      final customText = await showDialog<String>(
                        context: context,
                        builder: (context) {
                          final controller = TextEditingController();
                          return StatefulBuilder(
                            builder: (context, setDialogState) {
                              final textLength = controller.text.length;
                              return AlertDialog(
                                backgroundColor: dialogBg,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: borderColor),
                                ),
                                title: Text(
                                  '✍️ Napiš vlastní zprávu',
                                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextField(
                                      controller: controller,
                                      autofocus: true,
                                      maxLength: 60,
                                      style: TextStyle(color: textColor),
                                      onChanged: (val) {
                                        setDialogState(() {});
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Aktivuj svého kamaráda...',
                                        hintStyle: const TextStyle(color: Colors.white30),
                                        counterText: '$textLength / 60',
                                        counterStyle: TextStyle(color: textSecondary, fontSize: 11),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: Color(0xFFBFFF00)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, null),
                                    child: Text('Zpět', style: TextStyle(color: textSecondary)),
                                  ),
                                  ElevatedButton(
                                    onPressed: controller.text.trim().isEmpty
                                        ? null
                                        : () => Navigator.pop(context, controller.text.trim()),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFBFFF00),
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Potvrdit'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                      if (customText != null && customText.isNotEmpty) {
                        Navigator.pop(context, customText);
                      }
                    } else {
                      Navigator.pop(context, opt);
                    }
                  },
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text('Zrušit', style: TextStyle(color: textSecondary)),
            ),
          ],
        );
      },
    );

    if (selectedMsg == null) return;

    final now = DateTime.now();

    try {
      final myDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final myUsername = myDoc.data()?['username'] as String? ?? 'Uživatel';

      await _firestore.collection('activities').add({
        'uid': friendUid,
        'username': friendName,
        'type': 'nudge',
        'timestamp': FieldValue.serverTimestamp(),
        'details': {
          'message': 'Uživatel $myUsername tě popíchnul: "$selectedMsg"',
          'senderName': myUsername,
          'senderUid': currentUser.uid,
        },
      });

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
          backgroundColor: const Color(0xFF1B5E20),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nepodařilo se popíchnout kamaráda: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeRelationship(String targetUid, String targetName) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final isWhite = MainShell.themeNotifier.value == 'white';
    final dialogBg = isWhite ? Colors.white : const Color(0xFF37474F);
    final textColor = isWhite ? Colors.black : Colors.white;
    final textSecondary = isWhite ? Colors.black54 : Colors.white70;
    final borderColor = isWhite ? Colors.grey.shade300 : Colors.white10;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: borderColor),
        ),
        title: Text('Odebrat z přátel?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text('Opravdu chcete odebrat uživatele $targetName ze svých přátel?', style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Zrušit', style: TextStyle(color: textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
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
        SnackBar(
          content: Text('Uživatel $targetName byl odebrán z přátel.'),
          backgroundColor: const Color(0xFF263238),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chyba při rušení přátelství: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
    return ValueListenableBuilder<String>(
      valueListenable: MainShell.themeNotifier,
      builder: (context, theme, child) {
        final isWhite = theme == 'white';
        final bgColor = isWhite ? const Color(0xFFF9FBFC) : const Color(0xFF263238);
        final cardColor = isWhite ? Colors.white : const Color(0xFF1E272C);
        final textColor = isWhite ? Colors.black : Colors.white;
        final textSecondary = isWhite ? Colors.black54 : Colors.white70;
        final borderColor = isWhite ? Colors.grey.shade300 : Colors.white10;
        final appBarBg = isWhite ? Colors.white : const Color(0xFF1E272C);
        final appBarFg = isWhite ? Colors.black : Colors.white;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              'MOJI PŘÁTELÉ',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: appBarFg),
            ),
            centerTitle: true,
            backgroundColor: appBarBg,
            elevation: 0,
            iconTheme: IconThemeData(color: appBarFg),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add, color: Color(0xFFBFFF00)),
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
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFBFFF00)));
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
                          backgroundColor: cardColor,
                          child: Icon(Icons.people_outline, size: 50, color: const Color(0xFFBFFF00).withOpacity(0.8)),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Zatím tu nikdo není',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Přidej si své kamarády pomocí jejich kódu nebo QR kódu, abys mohl sledovat jejich pokroky a popichovat je k pohybu!',
                          style: TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
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
                            backgroundColor: const Color(0xFFBFFF00),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: friends.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    final uid = friend['uid'] as String? ?? '';
                    final username = friend['username'] as String? ?? 'Uživatel';
                    final code = friend['friend_code'] as String? ?? '';
                    final isLocked = _isNudgeLocked(uid);
                    final remainingTime = _getRemainingNudgeTimeText(uid);

                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FriendProfileScreen(friendUid: uid),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: borderColor, width: 1.5),
                                ),
                                child: CircleAvatar(
                                  backgroundColor: bgColor,
                                  foregroundColor: const Color(0xFFBFFF00),
                                  child: Text(
                                    username.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      username,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                    ),
                                    const SizedBox(height: 2),
                                    if (code.isNotEmpty)
                                      Text(
                                        code,
                                        style: TextStyle(fontSize: 13, color: textSecondary),
                                      ),
                                    if (isLocked && remainingTime.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Popíchnuto (znovu za $remainingTime)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFBFFF00),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  isLocked ? Icons.timer_outlined : Icons.notifications_active,
                                  color: isLocked ? textSecondary.withOpacity(0.3) : const Color(0xFFBFFF00),
                                ),
                                tooltip: isLocked ? 'Popíchnutí uzamčeno' : 'Popíchnout k pohybu',
                                onPressed: isLocked ? null : () => _nudgeFriend(uid, username),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove, color: Colors.redAccent),
                                tooltip: 'Odebrat z přátel',
                                onPressed: () => _removeRelationship(uid, username),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
