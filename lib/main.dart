import 'package:flutter/material.dart';

import 'features/gamification/gamification_screen.dart';
import 'features/maps/maps_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shop/shop_screen.dart';

void main() {
  runApp(const HejbejSeApp());
}

/// Kořenová aplikace – později sem přijde téma z [core/theme].
class HejbejSeApp extends StatelessWidget {
  const HejbejSeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hejbej se',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _MainShell(),
    );
  }
}

/// Jednoduchý „karbonát“ se čtyřmi moduly – dokud nepřijde vlastní navigace/router.
class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  static const List<Widget> _screens = [
    MapsScreen(),
    GamificationScreen(),
    ProfileScreen(),
    ShopScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapy'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Hra'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Obchod'),
        ],
      ),
    );
  }
}
