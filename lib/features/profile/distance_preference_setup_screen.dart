import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main_shell.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Nastavení tras',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: const Color(0xFF263238),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: AppLogo(size: 72)),
                        const SizedBox(height: 18),
                        const Text(
                          'Jak moc chceš chodit?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.black,
                            color: Color(0xFF263238),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Zvol si své ideální vzdálenosti. Podle nich ti budeme generovat herní a objevovací trasy v okolí.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                        const SizedBox(height: 24),
                        
                        _buildRangeCard(
                          title: '🥾 Pěší okruhy',
                          subtitle: 'Optimální vzdálenost pro tvé procházky.',
                          minLabel: '${_walkMin.toStringAsFixed(0)} km',
                          maxLabel: '${_walkMax.toStringAsFixed(0)} km',
                          onMinChanged: (value) => setState(() => _walkMin = value),
                          onMaxChanged: (value) => setState(() => _walkMax = value),
                          minValue: _walkMin,
                          maxValue: _walkMax,
                          rangeMin: 2.0,
                          rangeMax: 10.0,
                          sliderColor: const Color(0xFF5C9E00),
                        ),
                        const SizedBox(height: 18),
                        _buildRangeCard(
                          title: '🚴 Cyklotrasy',
                          subtitle: 'Rozsah pro pohodlné a bezpečné vyjížďky.',
                          minLabel: '${_bikeMin.toStringAsFixed(0)} km',
                          maxLabel: '${_bikeMax.toStringAsFixed(0)} km',
                          onMinChanged: (value) => setState(() => _bikeMin = value),
                          onMaxChanged: (value) => setState(() => _bikeMax = value),
                          minValue: _bikeMin,
                          maxValue: _bikeMax,
                          rangeMin: 5.0,
                          rangeMax: 40.0,
                          sliderColor: const Color(0xFF1B5E20),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    if (_saving)
                      const Center(child: CircularProgressIndicator(color: Color(0xFF5C9E00)))
                    else
                      ElevatedButton(
                        onPressed: _savePreferences,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBFFF00),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          'ULOŽIT A POKRAČOVAT',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
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
    required Color sliderColor,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF263238)),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min: $minLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238))),
                Text('Max: $maxLabel', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF263238))),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: sliderColor,
                inactiveTrackColor: sliderColor.withOpacity(0.15),
                thumbColor: sliderColor,
                overlayColor: sliderColor.withOpacity(0.12),
                valueIndicatorColor: sliderColor,
              ),
              child: Column(
                children: [
                  Slider(
                    value: minValue,
                    min: rangeMin,
                    max: rangeMax - 2,
                    divisions: ((rangeMax - rangeMin - 2).round()).clamp(1, 20),
                    label: 'Min: $minLabel',
                    onChanged: onMinChanged,
                  ),
                  Slider(
                    value: maxValue,
                    min: minValue + 1,
                    max: rangeMax,
                    divisions: ((rangeMax - minValue - 1).round()).clamp(1, 20),
                    label: 'Max: $maxLabel',
                    onChanged: onMaxChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
