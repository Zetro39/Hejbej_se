import 'package:flutter/material.dart';

/// Modul Profil – účet, nastavení, skupiny (později).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: const Center(child: Text('Modul Profil')),
    );
  }
}
