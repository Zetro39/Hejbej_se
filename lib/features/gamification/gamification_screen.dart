import 'package:flutter/material.dart';

/// Modul Gamifikace – XP, striky, achievementy (později).
class GamificationScreen extends StatelessWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gamifikace')),
      body: const Center(child: Text('Modul Gamifikace')),
    );
  }
}
