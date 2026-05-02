import 'package:flutter/material.dart';

/// Modul Mapy – Mapy.cz, trasy, GPS (později).
class MapsScreen extends StatelessWidget {
  const MapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapy')),
      body: const Center(child: Text('Modul Mapy')),
    );
  }
}
