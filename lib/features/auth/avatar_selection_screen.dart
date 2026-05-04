import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_screen.dart';

/// Screen for selecting user avatar
class AvatarSelectionScreen extends StatefulWidget {
  const AvatarSelectionScreen({super.key});

  @override
  State<AvatarSelectionScreen> createState() => _AvatarSelectionScreenState();
}

class _AvatarSelectionScreenState extends State<AvatarSelectionScreen> {
  String? _selectedAvatar;

  final List<Map<String, dynamic>> _avatars = [
    {
      'id': 'boy',
      'label': 'Chlapec',
      'image': 'assets/images/boy.png',
    },
    {
      'id': 'girl',
      'label': 'Dívka',
      'image': 'assets/images/girl.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedAvatar();
  }

  Future<void> _loadSelectedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedAvatar = prefs.getString('selected_avatar');
    });
  }

  Future<void> _saveSelectedAvatar(String avatarId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_avatar', avatarId);
    setState(() {
      _selectedAvatar = avatarId;
    });
  }

  void _onContinue() {
    if (_selectedAvatar != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyber svého hrdinu'),
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Vyber svého avatar',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Tento avatar bude reprezentovat tvůj pokrok v aplikaci',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Row(
              children: _avatars.map((avatar) {
                final isSelected = _selectedAvatar == avatar['id'];
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _saveSelectedAvatar(avatar['id']),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? Colors.lime : Colors.lightBlue.shade200,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        elevation: isSelected ? 8 : 2,
                        color: isSelected ? Colors.lightBlue.shade50 : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.transparent,
                                child: ClipOval(
                                  child: Image.asset(
                                    avatar['image'],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                avatar['label'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.lime.shade900 : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedAvatar != null ? _onContinue : null,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>(
                    (states) {
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade300;
                      }
                      return Colors.lime;
                    },
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>(
                    (states) {
                      if (states.contains(WidgetState.disabled)) {
                        return Colors.grey.shade500;
                      }
                      return Colors.black;
                    },
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                child: const Text(
                  'POKRAČOVAT',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}