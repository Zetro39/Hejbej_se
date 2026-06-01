import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main_shell.dart';
import '../../services/auth_service.dart';

class DistancePreferenceSetupScreen extends StatefulWidget {
  const DistancePreferenceSetupScreen({super.key});

  @override
  State<DistancePreferenceSetupScreen> createState() => _DistancePreferenceSetupScreenState();
}

class _DistancePreferenceSetupScreenState extends State<DistancePreferenceSetupScreen> {
  double _walkMin = 2.0;
  double _walkMax = 5.0;
  double _bikeMin = 10.0;
  double _bikeMax = 30.0;
  bool _saving = false;

  Future<void> _savePreferences() async {
    setState(() {
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('walk_range_min', _walkMin);
    await prefs.setDouble('walk_range_max', _walkMax);
    await prefs.setDouble('bike_range_min', _bikeMin);
    await prefs.setDouble('bike_range_max', _bikeMax);

    final user = AuthService().currentUser;
    if (user != null) {
      await AuthService().saveProfile(user.uid, {
        'walk_range_min': _walkMin,
        'walk_range_max': _walkMax,
        'bike_range_min': _bikeMin,
        'bike_range_max': _bikeMax,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    final userName = await AuthService().getUserName() ?? user?.email ?? 'Hráč';
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MainShell(userName: userName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nastavení tras'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Zvolte si svůj preferovaný vzdálenostní rozsah pro procházky a jízdu na kole.',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              _buildRangeCard(
                title: 'Pěší trasy',
                subtitle: 'Optimální rozsah pro vaše každodenní procházky.',
                minLabel: '${_walkMin.toStringAsFixed(0)} km',
                maxLabel: '${_walkMax.toStringAsFixed(0)} km',
                onMinChanged: (value) => setState(() => _walkMin = value),
                onMaxChanged: (value) => setState(() => _walkMax = value),
                minValue: _walkMin,
                maxValue: _walkMax,
                rangeMin: 2.0,
                rangeMax: 10.0,
              ),
              const SizedBox(height: 20),
              _buildRangeCard(
                title: 'Cyklistické trasy',
                subtitle: 'Rozsah pro pohodlné a bezpečné vyjížďky.',
                minLabel: '${_bikeMin.toStringAsFixed(0)} km',
                maxLabel: '${_bikeMax.toStringAsFixed(0)} km',
                onMinChanged: (value) => setState(() => _bikeMin = value),
                onMaxChanged: (value) => setState(() => _bikeMax = value),
                minValue: _bikeMin,
                maxValue: _bikeMax,
                rangeMin: 5.0,
                rangeMax: 40.0,
              ),
              const Spacer(),
              if (_saving)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(
                  onPressed: _savePreferences,
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(const Color(0xFFBFFF00)),
                    foregroundColor: WidgetStatePropertyAll(Colors.black),
                    padding: WidgetStatePropertyAll(const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  child: const Text(
                    'Uložit a pokračovat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRangeCard({
    required String title,
    required String subtitle,
    required String minLabel,
    required String maxLabel,
    required double minValue,
    required double maxValue,
    required double rangeMin,
    required double rangeMax,
    required ValueChanged<double> onMinChanged,
    required ValueChanged<double> onMaxChanged,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min: $minLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Max: $maxLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: minValue,
              min: rangeMin,
              max: rangeMax - 2,
              divisions: ((rangeMax - rangeMin - 2).round()).clamp(1, 20),
              label: minLabel,
              onChanged: onMinChanged,
            ),
            Slider(
              value: maxValue,
              min: minValue + 1,
              max: rangeMax,
              divisions: ((rangeMax - minValue - 1).round()).clamp(1, 20),
              label: maxLabel,
              onChanged: onMaxChanged,
            ),
          ],
        ),
      ),
    );
  }
}
