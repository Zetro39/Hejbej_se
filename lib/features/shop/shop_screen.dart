import 'package:flutter/material.dart';

/// Modul E-shop – „Chystáme pro vás“, merch (později).
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Obchod')),
      body: const Center(child: Text('Modul E-shop')),
    );
  }
}
