import 'package:flutter/material.dart';

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
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        backgroundColor: Colors.lightBlue.shade50.withOpacity(0.8),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map), label: 'Mapy'),
          NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Hra'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Obchod'),
        ],
      ),
    );
  }
}