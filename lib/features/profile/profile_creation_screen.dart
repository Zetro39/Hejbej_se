import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main_shell.dart';
import '../../services/auth_service.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final ImagePicker _picker = ImagePicker();
  
  // Data state
  DateTime? _birthDate;
  double _walkMin = 5.0;
  double _walkMax = 15.0;
  double _bikeMin = 20.0;
  double _bikeMax = 35.0;
  String _defaultActivity = 'foot'; // 'foot' or 'bike'
  
  String? _selectedAvatarBase64;
  String? _presetAvatarId = 'boy'; // Default preset
  File? _customImageFile;
  
  bool _isSaving = false;

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 150,
        maxHeight: 150,
        imageQuality: 80,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final base64String = base64Encode(bytes);
      setState(() {
        _selectedAvatarBase64 = 'base64:$base64String';
        _presetAvatarId = null;
        _customImageFile = File(image.path);
      });
    } catch (e) {
      debugPrint('Failed to pick image: $e');
    }
  }

  void _selectPresetAvatar(String id) {
    setState(() {
      _presetAvatarId = id;
      _selectedAvatarBase64 = null;
      _customImageFile = null;
    });
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1920),
      lastDate: today,
      locale: const Locale('cs', 'CZ'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.lightBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadejte prosím své datum narození.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = AuthService().currentUser;
    if (user == null) {
      setState(() => _isSaving = false);
      return;
    }

    final age = _calculateAge(_birthDate!);
    final avatarToSave = _selectedAvatarBase64 ?? _presetAvatarId ?? 'boy';

    final data = {
      'birth_date': Timestamp.fromDate(_birthDate!),
      'age': age,
      'walk_range_min': _walkMin,
      'walk_range_max': _walkMax,
      'bike_range_min': _bikeMin,
      'bike_range_max': _bikeMax,
      'default_activity': _defaultActivity,
      'selected_avatar': avatarToSave,
      'updated_at': FieldValue.serverTimestamp(),
    };

    try {
      // 1. Save locally in SharedPreferences first for instant responsiveness
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_avatar', avatarToSave);
      await prefs.setDouble('walk_range_min', _walkMin);
      await prefs.setDouble('walk_range_max', _walkMax);
      await prefs.setDouble('bike_range_min', _bikeMin);
      await prefs.setDouble('bike_range_max', _bikeMax);
      await prefs.setString('default_activity', _defaultActivity);
      await prefs.setString('birth_date', _birthDate!.toIso8601String());

      // 2. Write to Firestore with a timeout so it doesn't block redirection on slow networks
      try {
        await AuthService().saveProfile(user.uid, data).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firestore saveProfile timed out or failed: $e');
      }

      // Sync name & stats locally
      try {
        await AuthService().syncFirestoreToLocal().timeout(const Duration(seconds: 3));
      } catch (_) {}
      
      final userName = await AuthService().getUserName() ?? 'Hráč';

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(userName: userName)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nepodařilo se uložit profil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageText = _birthDate == null 
        ? 'Nevybráno' 
        : '${_birthDate!.day}. ${_birthDate!.month}. ${_birthDate!.year} (${_calculateAge(_birthDate!)} let)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doplnit informace'),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Přizpůsob si aplikaci na míru',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Vyplňte dodatečné údaje pro správné generování tras a odemčení her.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // SECTION 1: Avatar selection
              const Text(
                'Vyber nebo nahraj svůj profilový obrázek',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Boy Preset
                  Expanded(
                    child: _buildAvatarOption(
                      id: 'boy',
                      isSelected: _presetAvatarId == 'boy',
                      onTap: () => _selectPresetAvatar('boy'),
                      child: Image.asset('assets/images/boy.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Girl Preset
                  Expanded(
                    child: _buildAvatarOption(
                      id: 'girl',
                      isSelected: _presetAvatarId == 'girl',
                      onTap: () => _selectPresetAvatar('girl'),
                      child: Image.asset('assets/images/girl.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Custom Upload option
                  Expanded(
                    child: _buildAvatarOption(
                      id: 'custom',
                      isSelected: _selectedAvatarBase64 != null,
                      onTap: _pickImage,
                      child: _customImageFile != null
                          ? Image.file(_customImageFile!, fit: BoxFit.cover)
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, color: Colors.lightBlue, size: 28),
                                SizedBox(height: 4),
                                Text(
                                  'Vlastní fotka',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECTION 2: Birth Date Picker Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.lightBlue.shade50.withOpacity(0.4),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.lightBlue,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.cake),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Datum narození',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ageText,
                              style: TextStyle(
                                fontSize: 13, 
                                color: _birthDate == null ? Colors.black45 : Colors.lightBlue.shade800,
                                fontWeight: _birthDate == null ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _selectBirthDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.lightBlue,
                          side: const BorderSide(color: Colors.lightBlue),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Zvolit'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // SECTION 3: Activity type toggle (Pěšky / Na kole)
              const Text(
                'Výchozí typ aktivity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildActivityButton(
                      type: 'foot',
                      label: 'Pěšky',
                      icon: Icons.directions_walk,
                      isSelected: _defaultActivity == 'foot',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActivityButton(
                      type: 'bike',
                      label: 'Na kole',
                      icon: Icons.directions_bike,
                      isSelected: _defaultActivity == 'bike',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECTION 4: Kilometer Ranges Sliders
              const Text(
                'Preferovaný rozsah tras',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Walk Range Card
              _buildSliderCard(
                title: 'Pěší okruhy (Chůze)',
                subtitle: 'Nastavte minimální a maximální délku tras',
                minVal: _walkMin,
                maxVal: _walkMax,
                rangeMin: 5.0,
                rangeMax: 30.0,
                onMinChanged: (v) => setState(() => _walkMin = v),
                onMaxChanged: (v) => setState(() => _walkMax = v),
              ),

              const SizedBox(height: 16),

              // Bike Range Card
              _buildSliderCard(
                title: 'Cyklo okruhy (Kolo)',
                subtitle: 'Nastavte minimální a maximální délku vyjížděk',
                minVal: _bikeMin,
                maxVal: _bikeMax,
                rangeMin: 20.0,
                rangeMax: 50.0,
                onMinChanged: (v) => setState(() => _bikeMin = v),
                onMaxChanged: (v) => setState(() => _bikeMax = v),
              ),

              const SizedBox(height: 36),

              // SECTION 5: Save button
              if (_isSaving)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFFF00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: const Text(
                      'Uložit a vstoupit do hry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOption({
    required String id,
    required bool isSelected,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.lime : Colors.grey.shade200,
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.lime.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: child,
        ),
      ),
    );
  }

  Widget _buildActivityButton({
    required String type,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _defaultActivity = type),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? Colors.lightBlue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.lightBlue : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.lightBlue : Colors.black54),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.lightBlue : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String subtitle,
    required double minVal,
    required double maxVal,
    required double rangeMin,
    required double rangeMax,
    required ValueChanged<double> onMinChanged,
    required ValueChanged<double> onMaxChanged,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black45)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Min: ${minVal.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('Max: ${maxVal.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: minVal,
              min: rangeMin,
              max: rangeMax - 1,
              divisions: (rangeMax - rangeMin).round(),
              label: '${minVal.toStringAsFixed(0)} km',
              onChanged: onMinChanged,
            ),
            Slider(
              value: maxVal,
              min: minVal + 1,
              max: rangeMax,
              divisions: (rangeMax - minVal).round(),
              label: '${maxVal.toStringAsFixed(0)} km',
              onChanged: onMaxChanged,
            ),
          ],
        ),
      ),
    );
  }
}
