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
        title: const Text('HRY'),
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
              const SizedBox(height: 24),
              const Text(
                'Připravujeme další hry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildPlaceholderCard(context, 'Budoucí výzvy', 'Čeká na vás nové herní zážitky.'),
                    const SizedBox(height: 16),
                    _buildPlaceholderCard(context, 'Kroky a odměny', 'Elegantní design pro budoucí hry.'),
                    const SizedBox(height: 16),
                    _buildPlaceholderCard(context, 'Turnaje', 'Připravujeme speciální komunitní soutěže.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(BuildContext context, String title, String subtitle) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Icon(Icons.lock_outline, color: Colors.grey),
                SizedBox(width: 8),
                Text('Brzy dostupné', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
