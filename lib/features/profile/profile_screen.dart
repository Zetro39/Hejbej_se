import 'package:flutter/material.dart';

/// Modul Profil – uživatelské informace.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Kruhový prostor pro fotku
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.lightBlue, Colors.lime],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.lightBlue.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Jméno uživatele
                Text(
                  userName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),

                const SizedBox(height: 8),

                // Status
                Text(
                  'Hrdina',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.lightBlue.shade600,
                      ),
                ),

                const SizedBox(height: 40),

                // Level indicator
                _ProgressIndicator(
                  label: 'Level',
                  currentValue: 1,
                  maxValue: 2,
                  unit: 'Lvl',
                  color: Colors.lightBlue,
                ),

                const SizedBox(height: 24),

                // XP indicator
                _ProgressIndicator(
                  label: 'Zkušenosti',
                  currentValue: 0,
                  maxValue: 1000,
                  unit: 'XP',
                  color: Colors.lime,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget pro ukazatel pokroku s etiketu
class _ProgressIndicator extends StatelessWidget {
  final String label;
  final int currentValue;
  final int maxValue;
  final String unit;
  final Color color;

  const _ProgressIndicator({
    required this.label,
    required this.currentValue,
    required this.maxValue,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = currentValue / maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label a hodnota
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
            ),
            Text(
              '$currentValue / $maxValue $unit',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.lightBlue.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),

        const SizedBox(height: 4),

        // Procenta
        Text(
          '${(progress * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.lightBlue.shade600,
              ),
        ),
      ],
    );
  }
}
