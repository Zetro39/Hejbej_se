import 'dart:async';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';

import 'features/maps/maps_screen.dart';
import 'features/gamification/gamification_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.userName});

  final String userName;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _blocked = false;
  Timer? _verifyTimer;

  @override
  void initState() {
    super.initState();
    _checkBlocked();
    _verifyTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _checkBlocked();
    });
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBlocked() async {
    final blocked = await AuthService().isBlockedDueToUnverified();
    if (mounted) setState(() => _blocked = blocked);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      const GameScreen(),
      ProfileScreen(userName: widget.userName),
      const MapsScreen(),
      const LeaderboardScreen(),
      const ShopScreen(),
    ];

    return Scaffold(
      extendBody: true,
        body: _blocked
          ? _VerificationWall(onSignOut: () async {
              await AuthService().signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacementNamed('/');
            }, onResend: () async {
              final user = AuthService().currentUser;
              try {
                await user?.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Odeslán potvrzovací e-mail')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba při odesílání: $e')));
              }
            })
          : _screens[_index],
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: FloatingActionButton(
          onPressed: () => setState(() => _index = 2),
          backgroundColor: Colors.lime,
          elevation: 6,
          child: const Icon(Icons.map, size: 32, color: Colors.black),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SafeArea(
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavButton(icon: Icons.emoji_events, label: 'Hry', index: 0, selected: _index == 0, onTap: () => setState(() => _index = 0)),
                _NavButton(icon: Icons.person, label: 'Profil', index: 1, selected: _index == 1, onTap: () => setState(() => _index = 1)),
                const SizedBox(width: 56), // space for FAB
                _NavButton(icon: Icons.leaderboard, label: 'Leaderboard', index: 3, selected: _index == 3, onTap: () => setState(() => _index = 3)),
                _NavButton(icon: Icons.shopping_bag, label: 'Obchod', index: 4, selected: _index == 4, onTap: () => setState(() => _index = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? Colors.lightBlue : Colors.black54),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: selected ? Colors.lightBlue : Colors.black54, fontSize: 12)),
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