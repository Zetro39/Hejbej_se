import 'package:flutter/material.dart';

/// Modul Obchod – Připravujeme.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Obchod'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: const SafeArea(
        child: Center(
          child: Text(
            'PŘIPRAVUJEME',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.lightBlue,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
