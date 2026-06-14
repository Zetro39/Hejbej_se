import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import 'services/auth_service.dart';
import 'services/notification_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'features/maps/maps_screen.dart';
import 'features/gamification/gamification_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.userName});

  final String userName;
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('grey');

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 2;
  bool _blocked = false;
  Timer? _verifyTimer;
  StreamSubscription? _incomingFriendsSubscription;
  StreamSubscription<QuerySnapshot>? _activitiesSubscription;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  bool _showMapType = true;
  bool _showMapStyle = true;
  bool _showShareLocation = true;
  bool _showArNav = true;

  @override
  void initState() {
    super.initState();
    _setupActivitiesListener();
    SharedPreferences.getInstance().then((prefs) {
      final savedTheme = prefs.getString('design_theme') ?? 'grey';
      MainShell.themeNotifier.value = savedTheme;
      if (mounted) {
        setState(() {
          _showMapType = prefs.getBool('show_map_type') ?? true;
          _showMapStyle = prefs.getBool('show_map_style') ?? true;
          _showShareLocation = prefs.getBool('show_share_location') ?? true;
          _showArNav = prefs.getBool('show_ar_nav') ?? true;
        });
      }
    });
    _checkBlocked();
    _verifyTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkBlocked();
    });
    _listenForIncomingFriends();
    _initDeepLinks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Funguje to! Testovací build proběhl úspěšně.'),
          backgroundColor: Colors.lime,
          duration: Duration(seconds: 5),
        ),
      );
    });
  }

  void _loadMapPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showMapType = prefs.getBool('show_map_type') ?? true;
        _showMapStyle = prefs.getBool('show_map_style') ?? true;
        _showShareLocation = prefs.getBool('show_share_location') ?? true;
        _showArNav = prefs.getBool('show_ar_nav') ?? true;
      });
    }
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _incomingFriendsSubscription?.cancel();
    _activitiesSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _setupActivitiesListener() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await NotificationManager.updateUnreadCount();

    final prefs = await SharedPreferences.getInstance();
    int lastTimeMs = prefs.getInt('last_activity_listener_timestamp') ?? DateTime.now().millisecondsSinceEpoch;

    _activitiesSubscription = FirebaseFirestore.instance
        .collection('activities')
        .where('uid', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) async {
      final prefsInst = await SharedPreferences.getInstance();
      int currentSavedMs = prefsInst.getInt('last_activity_listener_timestamp') ?? lastTimeMs;

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data == null) continue;

          final ts = data['timestamp'] as Timestamp?;
          if (ts == null) continue;

          final ms = ts.millisecondsSinceEpoch;
          if (ms <= currentSavedMs) continue;

          final type = data['type'] as String?;
          final details = data['details'] as Map<String, dynamic>? ?? {};
          final message = details['message'] as String? ?? 'Nové upozornění';

          String title = 'Nové oznámení';
          if (type == 'nudge') {
            title = '👉 Šťouchnutí';
          } else if (type == 'friend_request') {
            title = '👥 Žádost o přátelství';
          } else if (type == 'challenge') {
            title = '🏆 Nová výzva';
          }

          await NotificationManager.saveNotification(
            title,
            message,
            senderUid: details['senderUid'] as String?,
          );

          if (ms > currentSavedMs) {
            currentSavedMs = ms;
            await prefsInst.setInt('last_activity_listener_timestamp', ms);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title: $message', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFFBFFF00),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'ZOBRAZIT',
                  textColor: Colors.blue.shade900,
                  onPressed: () {
                    setState(() {
                      _index = 2; // Switch to Maps tab where the bell is
                    });
                  },
                ),
              ),
            );
          }
        }
      }
    });
  }

  void _listenForIncomingFriends() {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    bool isFirstSnapshot = true;
    _incomingFriendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('friends')
        .where('status', isEqualTo: 'incoming')
        .snapshots()
        .listen((snapshot) {
      if (isFirstSnapshot) {
        isFirstSnapshot = false;
        return;
      }
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final username = data['username'] as String? ?? 'Někdo';
            final code = data['friend_code'] as String? ?? '';
            final displayName = code.isNotEmpty ? '$username$code' : username;
            _showFriendRequestNotification(displayName, change.doc.id);
          }
        }
      }
    });
  }

  void _showFriendRequestNotification(String displayName, String senderUid) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Colors.lightBlue, size: 28),
            SizedBox(width: 12),
            Text('Žádost o přátelství', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Uživatel $displayName tě chce přidat do přátel.',
          style: const TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zavřít', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptFriendRequest(senderUid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Přijmout', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptFriendRequest(String senderUid) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      final ref1 = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('friends')
          .doc(senderUid);
      batch.update(ref1, {
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ref2 = FirebaseFirestore.instance
          .collection('users')
          .doc(senderUid)
          .collection('friends')
          .doc(currentUser.uid);
      batch.update(ref2, {
        'status': 'friends',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Žádost o přátelství byla přijata! 🎉'),
          backgroundColor: Colors.lime,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nepodařilo se přijmout přátelství: $e')),
      );
    }
  }

  Future<void> _checkBlocked() async {
    final blocked = await AuthService().isBlockedDueToUnverified();
    if (mounted) setState(() => _blocked = blocked);
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }).catchError((err) {
      debugPrint('Error getting initial deep link: $err');
    });

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Error in deep link stream: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received deep link: $uri');
    final path = uri.path;
    final host = uri.host;
    if (path.contains('route') || host.contains('route')) {
      final dataParam = uri.queryParameters['data'];
      if (dataParam != null && dataParam.isNotEmpty) {
        _processIncomingRouteData(dataParam);
      }
    }
  }

  void _processIncomingRouteData(String rawData) {
    if (rawData.isEmpty) return;
    
    String jsonString = rawData;
    if (!rawData.trim().startsWith('{')) {
      try {
        final decodedBytes = base64Decode(rawData.trim());
        jsonString = utf8.decode(decodedBytes);
      } catch (_) {
        jsonString = rawData;
      }
    }

    MapsScreen.pendingSharedRouteNotifier.value = jsonString;

    if (mounted) {
      setState(() {
        _index = 2; // Switch to Maps tab
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: MainShell.themeNotifier,
      builder: (context, theme, child) {
        final isWhiteTheme = theme == 'white';
        final bgColor = isWhiteTheme ? const Color(0xFFF9FBFC) : const Color(0xFF263238);
        final navBgColor = isWhiteTheme ? Colors.white : const Color(0xFF1E272C);

        final List<Widget> _screens = [
          const GameScreen(),
          ProfileScreen(userName: widget.userName),
          MapsScreen(
            showMapType: _showMapType,
            showMapStyle: _showMapStyle,
            showShareLocation: _showShareLocation,
            showArNav: _showArNav,
          ),
          const LeaderboardScreen(),
          const ShopScreen(),
        ];

        return Scaffold(
          extendBody: true,
          backgroundColor: bgColor,
          body: _blocked
              ? _VerificationWall(
                  onSignOut: () async {
                    await AuthService().signOut();
                    if (!mounted) return;
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  onResend: () async {
                    final user = AuthService().currentUser;
                    try {
                      await user?.sendEmailVerification();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Odeslán potvrzovací e-mail')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při odesílání: $e')));
                    }
                  },
                )
              : _screens[_index],
          bottomNavigationBar: BottomAppBar(
            elevation: 8,
            color: navBgColor,
            surfaceTintColor: navBgColor,
            padding: EdgeInsets.zero,
            child: SafeArea(
              child: SizedBox(
                height: 72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavButton(
                      icon: Icons.emoji_events_outlined,
                      activeIcon: Icons.emoji_events_rounded,
                      label: 'Hry',
                      index: 0,
                      selected: _index == 0,
                      onTap: () => setState(() => _index = 0),
                      theme: theme,
                    ),
                    _NavButton(
                      icon: Icons.leaderboard_outlined,
                      activeIcon: Icons.leaderboard_rounded,
                      label: 'Žebříček',
                      index: 3,
                      selected: _index == 3,
                      onTap: () => setState(() => _index = 3),
                      theme: theme,
                    ),
                    GestureDetector(
                      onTap: () {
                        _loadMapPreferences();
                        setState(() => _index = 2);
                      },
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _index == 2 ? const Color(0xFFBFFF00) : (isWhiteTheme ? Colors.grey.shade200 : const Color(0xFF263238)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _index == 2 ? const Color(0xFFBFFF00) : (isWhiteTheme ? Colors.grey.shade300 : Colors.white10),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBFFF00).withOpacity(_index == 2 ? 0.35 : 0.0),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.map_rounded,
                          size: 26,
                          color: _index == 2 ? const Color(0xFF1B5E20) : (isWhiteTheme ? Colors.black54 : Colors.white70),
                        ),
                      ),
                    ),
                    _NavButton(
                      icon: Icons.shopping_bag_outlined,
                      activeIcon: Icons.shopping_bag_rounded,
                      label: 'Obchod',
                      index: 4,
                      selected: _index == 4,
                      onTap: () => setState(() => _index = 4),
                      theme: theme,
                    ),
                    _NavButton(
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profil',
                      index: 1,
                      selected: _index == 1,
                      onTap: () => setState(() => _index = 1),
                      theme: theme,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final String theme;

  const _NavButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isWhiteTheme = theme == 'white';
    final activeColor = isWhiteTheme ? const Color(0xFF1B5E20) : const Color(0xFFBFFF00);
    final activeBg = isWhiteTheme ? const Color(0xFF5C9E00).withOpacity(0.12) : const Color(0xFFBFFF00).withOpacity(0.12);
    final inactiveColor = isWhiteTheme ? Colors.black38 : Colors.white30;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? activeColor.withOpacity(0.12) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              selected ? activeIcon : icon,
              color: selected ? activeColor : inactiveColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : inactiveColor,
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationWall extends StatelessWidget {
  final Future<void> Function() onResend;
  final Future<void> Function() onSignOut;
  const _VerificationWall({required this.onResend, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Ověřte svůj e-mail', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Potvrďte svůj e-mail kliknutím na odkaz v e-mailu. Máte 1 hodinu od registrace; jinak bude přístup zablokován.'),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onResend, child: const Text('Znovu odeslat ověřovací e-mail')),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: () async => await onSignOut(), child: const Text('Odhlásit se')),
          ],
        ),
      ),
    );
  }
}