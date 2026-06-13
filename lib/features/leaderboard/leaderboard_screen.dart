import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'add_friends_screen.dart';
import 'friends_list_screen.dart';
import 'friend_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedTab = 0; // 0 = Week, 1 = Month, 2 = Overall
  bool _isSearching = false;
  Map<String, dynamic>? _searchResult;
  String? _searchError;

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

  Widget _buildMedal(int index) {
    if (index == 0) return const Text('🥇', style: TextStyle(fontSize: 24));
    if (index == 1) return const Text('🥈', style: TextStyle(fontSize: 24));
    if (index == 2) return const Text('🥉', style: TextStyle(fontSize: 24));
    return Text('${index + 1}.', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Uživatel není přihlášen')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: const Text(
          'Žebříček a Přátelé',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E272C),
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline_rounded, color: Colors.white70),
            tooltip: 'Moji přátelé',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded, color: Colors.white70),
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
                        color: const Color(0xFF1E272C),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12, width: 1.5),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Zadej přezdívku nebo kód (např. #PEPA456)',
                          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF1E272C),
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
                      color: const Color(0xFF1E272C),
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              _searchResult!['friend_code'],
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
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

            // Tab Selector [ Tento týden ] [ Tento měsíc ] [ Celkově ]
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0),
               child: Container(
                 decoration: BoxDecoration(
                   color: const Color(0xFF1E272C),
                   borderRadius: BorderRadius.circular(16),
                 ),
                 padding: const EdgeInsets.all(4),
                 child: Row(
                   children: [
                     _buildTabButton(0, 'Tento týden'),
                     _buildTabButton(1, 'Tento měsíc'),
                     _buildTabButton(2, 'Celkově'),
                   ],
                 ),
               ),
             ),

            const SizedBox(height: 16),

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
                        return const Center(child: Text('Chyba při načítání žebříčku.'));
                      }

                      // Dynamic Sorting
                      userDocs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>? ?? {};
                        final dataB = b.data() as Map<String, dynamic>? ?? {};

                        double valA = 0.0;
                        double valB = 0.0;

                        if (_selectedTab == 0) {
                          valA = (dataA['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                          valB = (dataB['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                        } else if (_selectedTab == 1) {
                          valA = (dataA['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                          valB = (dataB['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                        } else {
                          valA = (dataA['totalDistance'] as num?)?.toDouble() ?? 0.0;
                          valB = (dataB['totalDistance'] as num?)?.toDouble() ?? 0.0;
                        }

                        return valB.compareTo(valA);
                      });

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: userDocs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final doc = userDocs[index];
                          final data = doc.data() as Map<String, dynamic>? ?? {};
                          final isMe = doc.id == currentUser.uid;

                          final username = data['username'] ?? 'Uživatel';
                          final code = data['friend_code'] ?? '';
                          final firstName = data['first_name'] ?? '';
                          final lastName = data['last_name'] ?? '';
                          final fullName = '$firstName $lastName'.trim().isEmpty ? username : '$firstName $lastName';

                          double dist = 0.0;
                          if (_selectedTab == 0) {
                            dist = (data['weeklyDistance'] as num?)?.toDouble() ?? 0.0;
                          } else if (_selectedTab == 1) {
                            dist = (data['monthlyDistance'] as num?)?.toDouble() ?? 0.0;
                          } else {
                            dist = (data['totalDistance'] as num?)?.toDouble() ?? 0.0;
                          }

                          final itemContent = Container(
                            decoration: BoxDecoration(
                              color: isMe ? const Color(0xFF1B5E20).withOpacity(0.3) : const Color(0xFF1E272C),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isMe ? const Color(0xFFBFFF00).withOpacity(0.5) : Colors.white12,
                                width: 1.5,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Center(
                                    child: _buildMedal(index),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  backgroundColor: isMe ? const Color(0xFFBFFF00) : const Color(0xFF263238),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (code.isNotEmpty)
                                        Text(
                                          code,
                                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${dist.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isMe ? const Color(0xFFBFFF00) : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (isMe) {
                            return itemContent;
                          }

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FriendProfileScreen(friendUid: doc.id),
                                ),
                              );
                            },
                            child: itemContent,
                          );
                        },
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
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFBFFF00) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
