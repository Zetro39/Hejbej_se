import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'add_friends_screen.dart';
import 'friends_list_screen.dart';
import 'friend_profile_screen.dart';
import '../../main_shell.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedTimeFilter = 0; // 0 = Týden, 1 = Měsíc, 2 = Rok
  int _selectedScopeFilter = 0; // 0 = Přátelé, 1 = Celá ČR, 2 = Můj kraj
  String? _myKraj;
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadMyKraj();
  }

  Future<void> _loadMyKraj() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _myKraj = doc.data()?['kraj'] as String?;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // Task 1: Search users in Firestore by username or friend_code
  Future<void> _searchUser() async {
    final queryText = _searchController.text.trim();
    if (queryText.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResult = null;
      _searchError = null;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('Uživatel není přihlášen');

      QuerySnapshot query;
      final cleanInput = _cleanStringForSearch(queryText);

      // Try querying by clean fields first
      query = await _firestore
          .collection('users')
          .where('friend_code_clean', isEqualTo: cleanInput)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await _firestore
            .collection('users')
            .where('username_clean', isEqualTo: cleanInput)
            .limit(1)
            .get();
      }

      // Backward compatibility fallbacks
      if (query.docs.isEmpty) {
        if (queryText.startsWith('#')) {
          query = await _firestore
              .collection('users')
              .where('friend_code', isEqualTo: queryText.toUpperCase())
              .limit(1)
              .get();
        } else {
          query = await _firestore
              .collection('users')
              .where('username', isEqualTo: queryText.toLowerCase())
              .limit(1)
              .get();

          if (query.docs.isEmpty) {
            // Try searching friend code with added hashtag
            query = await _firestore
                .collection('users')
                .where('friend_code', isEqualTo: '#${queryText.toUpperCase()}')
                .limit(1)
                .get();
          }
        }
      }

      if (query.docs.isEmpty) {
        setState(() {
          _searchError = 'Uživatel nenalezen.';
          _isSearching = false;
        });
        return;
      }

      final doc = query.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      
      if (doc.id == currentUser.uid) {
        setState(() {
          _searchError = 'Nemůžete vyhledat sami sebe.';
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _searchResult = {
          'uid': doc.id,
          'username': data['username'] ?? 'Uživatel',
          'friend_code': data['friend_code'] ?? '',
          'first_name': data['first_name'] ?? '',
          'last_name': data['last_name'] ?? '',
        };
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Nastala chyba při vyhledávání: $e';
        _isSearching = false;
      });
    }
  }

  // Task 2: Send friend request
  Future<void> _sendRequest(Map<String, dynamic> target) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final currentDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final currentData = currentDoc.data() ?? {};

      final batch = _firestore.batch();

      final outgoingRef = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(target['uid']);
      batch.set(outgoingRef, {
        'uid': target['uid'],
        'username': target['username'],
        'friend_code': target['friend_code'],
        'status': 'outgoing',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final incomingRef = _firestore
          .collection('users')
          .doc(target['uid'])
          .collection('friends')
          .doc(currentUser.uid);
      batch.set(incomingRef, {
        'uid': currentUser.uid,
        'username': currentData['username'] ?? 'Uživatel',
        'friend_code': currentData['friend_code'] ?? '',
        'status': 'incoming',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      setState(() {}); // refresh UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nepodařilo se poslat žádost: $e')));
    }
  }

  // Task 2: Accept friend request
  Future<void> _acceptRequest(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final batch = _firestore.batch();

      final ref1 = _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(targetUid);
      batch.update(ref1, {
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ref2 = _firestore
          .collection('users')
          .doc(targetUid)
          .collection('friends')
          .doc(currentUser.uid);
      batch.update(ref2, {
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při přijetí přátelství: $e')));
    }
  }

  // Task 2: Cancel/Decline/Remove relationship
  Future<void> _removeRelationship(String targetUid) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

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
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při rušení přátelství: $e')));
    }
  }

  Stream<List<Map<String, dynamic>>> _getFriendsListStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.data()).toList());
  }

  Stream<List<DocumentSnapshot>> _getLeaderboardUsersStream(List<String> friendUids) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    if (_selectedScopeFilter == 1) {
      // Celá ČR - order by selected field and limit to top 50
      String orderField = 'weeklyDistance';
      if (_selectedTimeFilter == 1) {
        orderField = 'monthlyDistance';
      } else if (_selectedTimeFilter == 2) {
        orderField = 'yearlyDistance';
      }
      return _firestore
          .collection('users')
          .orderBy(orderField, descending: true)
          .limit(50)
          .snapshots()
          .map((snap) => snap.docs);
    } else if (_selectedScopeFilter == 2) {
      // Můj kraj - filter by kraj and limit to 100, sorting will be client side
      final queryKraj = _myKraj ?? 'Praha';
      return _firestore
          .collection('users')
          .where('kraj', isEqualTo: queryKraj)
          .limit(100)
          .snapshots()
          .map((snap) => snap.docs);
    } else {
      // Pouze přátelé
      List<String> uids = [currentUser.uid, ...friendUids];
      if (uids.length > 30) {
        uids = uids.sublist(0, 30); // Firestore whereIn limit
      }
      return _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids)
          .snapshots()
          .map((snap) => snap.docs);
    }
  }

  Widget _buildMedal(int index, Color textSecondary) {
    if (index == 0) return const Text('🥇', style: TextStyle(fontSize: 24));
    if (index == 1) return const Text('🥈', style: TextStyle(fontSize: 24));
    if (index == 2) return const Text('🥉', style: TextStyle(fontSize: 24));
    return Text('${index + 1}.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textSecondary));
  }

  Widget _buildPodium(List<DocumentSnapshot> top3, String currentUid, Color cardColor, Color textColor, Color textSecondary, Color borderColor, bool isWhite) {
    if (top3.isEmpty) return const SizedBox();

    final List<DocumentSnapshot?> podiumList = List.filled(3, null);
    if (top3.isNotEmpty) podiumList[1] = top3[0];
    if (top3.length > 1) podiumList[0] = top3[1];
    if (top3.length > 2) podiumList[2] = top3[2];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (podiumList[0] != null)
            _buildPodiumCol(podiumList[0]!, 2, 70, Colors.grey.shade400, '🥈', currentUid, textColor, textSecondary, isWhite)
          else
            const Expanded(child: SizedBox()),
          if (podiumList[1] != null)
            _buildPodiumCol(podiumList[1]!, 1, 95, const Color(0xFFFFD700), '👑', currentUid, textColor, textSecondary, isWhite)
          else
            const Expanded(child: SizedBox()),
          if (podiumList[2] != null)
            _buildPodiumCol(podiumList[2]!, 3, 45, const Color(0xFFCD7F32), '🥉', currentUid, textColor, textSecondary, isWhite)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _buildPodiumCol(
    DocumentSnapshot doc,
    int rank,
    double height,
    Color rankColor,
    String badge,
    String currentUid,
    Color textColor,
    Color textSecondary,
    bool isWhite,
  ) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final username = data['username'] ?? 'Uživatel';
    final firstName = data['first_name'] ?? '';
    final lastName = data['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName';
    final isMe = doc.id == currentUid;

    double dist = 0.0;
    if (_selectedTimeFilter == 0) {
      dist = (data['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
    } else if (_selectedTimeFilter == 1) {
      dist = (data['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
    } else {
      dist = (data['yearlyDistance'] as num?)?.toDouble() ?? 0.0;
    }

    final List<Color> gradientColors = rank == 1
        ? [const Color(0xFFFFD700).withOpacity(0.35), const Color(0xFFFFD700).withOpacity(0.05)]
        : rank == 2
            ? [const Color(0xFFC0C0C0).withOpacity(0.25), const Color(0xFFC0C0C0).withOpacity(0.03)]
            : [const Color(0xFFCD7F32).withOpacity(0.20), const Color(0xFFCD7F32).withOpacity(0.02)];

    final borderTopColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : const Color(0xFFCD7F32);

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: borderTopColor.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: rank == 1 ? 32 : 26,
                  backgroundColor: isMe ? const Color(0xFFBFFF00) : borderTopColor,
                  child: CircleAvatar(
                    radius: rank == 1 ? 29 : 23,
                    backgroundColor: const Color(0xFF263238),
                    child: Text(
                      fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: rank == 1 ? 18 : 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: rank == 1 ? -20 : -14,
                child: Text(
                  badge,
                  style: TextStyle(fontSize: rank == 1 ? 24 : 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              isMe ? 'Ty' : fullName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: rank == 1 ? 13 : 11,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            '${dist.toStringAsFixed(1)} km',
            style: TextStyle(
              fontSize: rank == 1 ? 12 : 10,
              color: isMe ? const Color(0xFFBFFF00) : textSecondary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Container(
            height: height,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                top: BorderSide(color: borderTopColor, width: 3.0),
                left: BorderSide(color: borderTopColor.withOpacity(0.3), width: 1.0),
                right: BorderSide(color: borderTopColor.withOpacity(0.3), width: 1.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: borderTopColor.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: borderTopColor.withOpacity(0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: rank == 1 ? 36 : 28,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(1, 1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Uživatel není přihlášen')));
    }

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

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(
              'Žebříček a Přátelé',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5, color: appBarFg),
            ),
            centerTitle: true,
            backgroundColor: appBarBg,
            foregroundColor: appBarFg,
            elevation: 0,
            iconTheme: IconThemeData(color: appBarFg),
            actions: [
              IconButton(
                icon: Icon(Icons.people_outline_rounded, color: appBarFg.withOpacity(0.7)),
                tooltip: 'Moji přátelé',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FriendsListScreen()),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.person_add_alt_rounded, color: appBarFg.withOpacity(0.7)),
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
            child: Column(
              children: [
                // Search Input Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: TextStyle(color: textColor, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Zadej přezdívku nebo kód (např. #PEPA456)',
                              hintStyle: TextStyle(color: textSecondary.withOpacity(0.5), fontSize: 14),
                              filled: true,
                              fillColor: cardColor,
                              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFBFFF00)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFBFFF00), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBFFF00).withOpacity(0.3),
                              blurRadius: 10,
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
                          onPressed: _searchUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Hledat', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Result Panel
                if (_isSearching)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  )
                else if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(_searchError!, style: const TextStyle(color: Colors.red)),
                  )
                else if (_searchResult != null)
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _getFriendsListStream(),
                    builder: (context, snapshot) {
                      final friends = snapshot.data ?? [];
                      final relationship = friends.firstWhere(
                        (f) => f['uid'] == _searchResult!['uid'],
                        orElse: () => <String, dynamic>{},
                      );
                      final status = relationship['status'] as String?;

                      Widget actionButton;
                      if (status == null) {
                        actionButton = ElevatedButton.icon(
                          onPressed: () => _sendRequest(_searchResult!),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Přidat'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.lime, foregroundColor: Colors.black),
                        );
                      } else if (status == 'outgoing') {
                        actionButton = OutlinedButton.icon(
                          onPressed: () => _removeRelationship(_searchResult!['uid']),
                          icon: const Icon(Icons.close, size: 18, color: Colors.red),
                          label: const Text('Zrušit žádost', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                        );
                      } else if (status == 'incoming') {
                        actionButton = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              onPressed: () => _acceptRequest(_searchResult!['uid']),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.lime, foregroundColor: Colors.black),
                              child: const Text('Přijmout'),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton(
                              onPressed: () => _removeRelationship(_searchResult!['uid']),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                              child: const Icon(Icons.close, color: Colors.red, size: 16),
                            ),
                          ],
                        );
                      } else {
                        actionButton = OutlinedButton.icon(
                          onPressed: () => _removeRelationship(_searchResult!['uid']),
                          icon: const Icon(Icons.person_remove, size: 18, color: Colors.grey),
                          label: const Text('Přátelé', style: TextStyle(color: Colors.grey)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.grey)),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFFF00).withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_searchResult!['first_name']} ${_searchResult!['last_name']}'.trim().isEmpty
                                      ? _searchResult!['username']
                                      : '${_searchResult!['first_name']} ${_searchResult!['last_name']}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                ),
                                Text(
                                  _searchResult!['friend_code'],
                                  style: TextStyle(color: textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                            actionButton,
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 8),

                // Time & Scope Filters
                _buildTimeFilterRow(cardColor, textColor, textSecondary, borderColor),
                _buildScopeFilterRow(cardColor, textColor, textSecondary, borderColor),

                const SizedBox(height: 8),

                // Leaderboard List
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _getFriendsListStream(),
                    builder: (context, friendsSnapshot) {
                      if (!friendsSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final allConnections = friendsSnapshot.data ?? [];
                      final friendUids = allConnections
                          .where((f) => f['status'] == 'friends')
                          .map((f) => f['uid'] as String)
                          .toList();

                      return StreamBuilder<List<DocumentSnapshot>>(
                        stream: _getLeaderboardUsersStream(friendUids),
                        builder: (context, usersSnapshot) {
                          if (!usersSnapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final userDocs = usersSnapshot.data ?? [];

                          if (userDocs.isEmpty) {
                            return const Center(child: Text('Žádná data v tomto žebříčku.'));
                          }

                          // Dynamic Sorting
                          userDocs.sort((a, b) {
                            final dataA = a.data() as Map<String, dynamic>? ?? {};
                            final dataB = b.data() as Map<String, dynamic>? ?? {};

                            double valA = 0.0;
                            double valB = 0.0;

                            if (_selectedTimeFilter == 0) {
                              valA = (dataA['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                              valB = (dataB['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                            } else if (_selectedTimeFilter == 1) {
                              valA = (dataA['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                              valB = (dataB['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                            } else {
                              valA = (dataA['yearlyDistance'] as num? ?? dataA['totalDistance'] as num?)?.toDouble() ?? 0.0;
                              valB = (dataB['yearlyDistance'] as num? ?? dataB['totalDistance'] as num?)?.toDouble() ?? 0.0;
                            }

                            return valB.compareTo(valA);
                          });

                          final top3 = userDocs.take(3).toList();
                          final restUsers = userDocs.skip(3).toList();

                          return Column(
                            children: [
                              _buildPodium(top3, currentUser.uid, cardColor, textColor, textSecondary, borderColor, isWhite),
                              const SizedBox(height: 8),
                              Expanded(
                                child: restUsers.isEmpty
                                    ? Center(
                                        child: Text(
                                          'Žádní další uživatelé',
                                          style: TextStyle(color: textSecondary, fontSize: 14),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        itemCount: restUsers.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                                        itemBuilder: (context, index) {
                                          final doc = restUsers[index];
                                          final actualRankIndex = index + 3;
                                          final data = doc.data() as Map<String, dynamic>? ?? {};
                                          final isMe = doc.id == currentUser.uid;

                                          final username = data['username'] ?? 'Uživatel';
                                          final code = data['friend_code'] ?? '';
                                          final firstName = data['first_name'] ?? '';
                                          final lastName = data['last_name'] ?? '';
                                          final fullName = '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName';

                                          double dist = 0.0;
                                          if (_selectedTimeFilter == 0) {
                                            dist = (data['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                                          } else if (_selectedTimeFilter == 1) {
                                            dist = (data['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                                          } else {
                                            dist = (data['yearlyDistance'] as num? ?? data['totalDistance'] as num?)?.toDouble() ?? 0.0;
                                          }

                                          return Container(
                                            decoration: BoxDecoration(
                                              color: isMe ? const Color(0xFF1B5E20).withOpacity(0.3) : cardColor,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isMe ? const Color(0xFFBFFF00).withOpacity(0.5) : borderColor,
                                                width: 1.5,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 40,
                                                  child: Center(
                                                    child: _buildMedal(actualRankIndex, textSecondary),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                CircleAvatar(
                                                  backgroundColor: isMe ? const Color(0xFFBFFF00) : (isWhite ? Colors.grey.shade100 : const Color(0xFF263238)),
                                                  foregroundColor: isMe ? Colors.black : const Color(0xFFBFFF00),
                                                  child: Text(fullName.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        isMe ? '$fullName (Ty)' : fullName,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                      if (code.isNotEmpty)
                                                        Text(
                                                          code,
                                                          style: TextStyle(fontSize: 12, color: textSecondary),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Text(
                                                  '${dist.toStringAsFixed(1)} km',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: isMe ? const Color(0xFFBFFF00) : textColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeFilterRow(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildFilterButton(true, 0, 'Týden', textSecondary),
            _buildFilterButton(true, 1, 'Měsíc', textSecondary),
            _buildFilterButton(true, 2, 'Rok', textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeFilterRow(Color cardColor, Color textColor, Color textSecondary, Color borderColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildFilterButton(false, 0, 'Pouze přátelé', textSecondary),
            _buildFilterButton(false, 1, 'Celá ČR', textSecondary),
            _buildFilterButton(false, 2, 'Můj kraj', textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(bool isTimeFilter, int index, String title, Color unselectedColor) {
    final isSelected = isTimeFilter 
        ? _selectedTimeFilter == index 
        : _selectedScopeFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (isTimeFilter) {
              _selectedTimeFilter = index;
            } else {
              _selectedScopeFilter = index;
            }
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFBFFF00) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.black : unselectedColor,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
