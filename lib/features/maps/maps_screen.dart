import 'package:flutter/material.dart';

/// Modul Mapy – Placeholder pro GPS mapu.
class MapsScreen extends StatelessWidget {
  const MapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapy'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top overlay with task
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              color: Colors.lightBlue.shade50,
              child: Row(
                children: [
                  Icon(
                    Icons.task_alt,
                    color: Colors.lightBlue,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Úkol: Najdi nejbližší park',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.lightBlue.shade900,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // Map placeholder
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.lightBlue.shade200,
                    width: 2,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 80,
                        color: Colors.lightBlue,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'GPS Mapa se připravuje',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.lightBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom scan button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Spouštím skenování okolí...'),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.radar,
                    size: 32,
                  ),
                  label: const Text(
                    'SKENOVAT OKOLÍ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.lime),
                    foregroundColor: WidgetStateProperty.all(Colors.black),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
