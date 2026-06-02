import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.emoji_events, size: 72, color: Colors.amber),
                SizedBox(height: 16),
                Text('Leaderboard bude brzy k dispozici', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Text('Zde uvidíte nejlepší hráče a žebříček.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
