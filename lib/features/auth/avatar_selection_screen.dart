import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../login_screen.dart';
import '../../widgets/app_logo.dart';

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
      'emoji': '👦',
      'description': 'Mladý dobrodruh připravený pokořit stovky kilometrů.',
    },
    {
      'id': 'girl',
      'label': 'Dívka',
      'emoji': '👧',
      'description': 'Bystrá běžkyně odhodlaná projít celou přírodní říší.',
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
    Feedback.forLongPress(context);
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Výběr hrdiny',
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
            final double height = constraints.maxHeight;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height - 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 10),
                        const Center(child: AppLogo(size: 80)),
                        const SizedBox(height: 18),
                        const Text(
                          'Kdo tě bude reprezentovat?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF263238),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Vyber si svého avatar, který bude provázet tvůj pohyb a pokrok v aplikaci.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Avatar Cards List
                    Row(
                      children: _avatars.map((avatar) {
                        final isSelected = _selectedAvatar == avatar['id'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _saveSelectedAvatar(avatar['id']),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              margin: const EdgeInsets.symmetric(horizontal: 8.0),
                              transform: Matrix4.identity()..scale(isSelected ? 1.04 : 0.96),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF5C9E00) : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected 
                                        ? const Color(0xFF5C9E00).withOpacity(0.15) 
                                        : Colors.black.withOpacity(0.04),
                                    blurRadius: isSelected ? 16 : 8,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: isSelected 
                                            ? const Color(0xFFBFFF00).withOpacity(0.2) 
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          avatar['emoji'] as String,
                                          style: const TextStyle(fontSize: 40),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      avatar['label'] as String,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF263238),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      avatar['description'] as String,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.black54,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _selectedAvatar != null ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFFF00),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: _selectedAvatar != null ? 3 : 0,
                      ),
                      child: const Text(
                        'POKRAČOVAT',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}