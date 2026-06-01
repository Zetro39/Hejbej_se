import 'dart:async';
import 'package:flutter/material.dart';

import 'services/auth_service.dart';

import 'features/maps/maps_screen.dart';
import 'features/gamification/gamification_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shop/shop_screen.dart';

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
      const MapsScreen(),
      const GameScreen(),
      ProfileScreen(userName: widget.userName),
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
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        backgroundColor: Colors.lightBlue.shade50.withOpacity(0.8),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapy'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'HRY'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Obchod'),
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