import 'package:flutter/material.dart';

/// Modul Hra – kroky, cíle a progres.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const int steps = 0;
    const int goal = 10000;
    final double progress = steps / goal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hra'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.lightBlue.shade100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kroků dnes',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.lightBlue.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '0',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlue,
                            ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Cíl: 10 000 kroků',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.black87,
                            ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 18,
                          backgroundColor: Colors.lightBlue.shade100,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.lime),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '0.0 %',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.lightBlue.shade600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
