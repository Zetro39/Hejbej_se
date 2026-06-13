import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../login_screen.dart';
import '../../main_shell.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_logo.dart';

class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> {
  final ImagePicker _picker = ImagePicker();
  
  // Text controllers for basic info
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  int _currentStep = 0; // 0: Personal details, 1: Avatar/Hero, 2: Activity Goals

  @override
  void initState() {
    super.initState();
    _loadExistingProfileBasics();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfileBasics() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() ?? {};
        setState(() {
          _firstNameController.text = data['first_name'] as String? ?? '';
          _lastNameController.text = data['last_name'] as String? ?? '';
          _usernameController.text = data['username'] as String? ?? '';
          _dailyStepsGoal = data['daily_steps_goal'] as int? ?? 10000;
        });
      }
    } catch (_) {}
  }

  // Data state
  DateTime? _birthDate;
  double _walkMin = 5.0;
  double _walkMax = 15.0;
  double _bikeMin = 20.0;
  double _bikeMax = 35.0;
  String _defaultActivity = 'foot'; // 'foot' or 'bike'
  int _dailyStepsGoal = 10000;
  
  String? _selectedAvatarBase64;
  String? _presetAvatarId = 'boy'; // Default preset
  File? _customImageFile;
  
  String _gender = 'male'; // 'male' or 'female'
  String _adultMaleOption = 'man'; // 'man' or 'chlap'
  bool _isSaving = false;

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _updateAssignedAvatar() {
    if (_birthDate == null) {
      setState(() {
        _presetAvatarId = _gender == 'male' ? 'boy' : 'girl';
      });
      return;
    }

    final age = _calculateAge(_birthDate!);
    setState(() {
      if (age < 18) {
        _presetAvatarId = _gender == 'male' ? 'boy' : 'girl';
      } else {
        if (_gender == 'female') {
          _presetAvatarId = 'woman';
        } else {
          _presetAvatarId = _adultMaleOption; // 'man' or 'chlap'
        }
      }
    });
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
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFBFFF00), // Neon Lime
              onPrimary: Color(0xFF263238), // Dark Charcoal
              surface: Color(0xFF263238),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF263238),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
      _updateAssignedAvatar();
    }
  }

  String _cleanStringForSearch(String input) {
    var str = input.toLowerCase().trim();
    const diacritics = {
      'á': 'a', 'č': 'c', 'ď': 'd', 'é': 'e', 'ě': 'e', 'í': 'i', 'ň': 'n', 
      'ó': 'o', 'ř': 'r', 'š': 's', 'ť': 't', 'ú': 'u', 'ů': 'u', 'ý': 'y', 'ž': 'z'
    };
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      buffer.write(diacritics[char] ?? char);
    }
    return buffer.toString().replaceAll('#', '');
  }

  Future<void> _saveProfile() async {
    final enteredUsername = _usernameController.text.trim();
    if (enteredUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadejte prosím herní přezdívku.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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

    try {
      Map<String, dynamic> existingData = {};
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 4));
        existingData = docSnap.data() ?? {};
      } catch (e) {
        debugPrint('Failed to get user doc from Firestore (offline?): $e');
      }

      String finalFriendCode = existingData['friend_code'] as String? ?? '';
      
      if (finalFriendCode.isEmpty || existingData['username'] != enteredUsername) {
        finalFriendCode = '#${enteredUsername.toUpperCase()}${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
      }

      final age = _calculateAge(_birthDate!);
      final avatarToSave = _selectedAvatarBase64 ?? _presetAvatarId ?? 'boy';

      final data = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'username': enteredUsername,
        'username_clean': _cleanStringForSearch(enteredUsername),
        'friend_code': finalFriendCode,
        'friend_code_clean': _cleanStringForSearch(finalFriendCode),
        'birth_date': Timestamp.fromDate(_birthDate!),
        'age': age,
        'gender': _gender,
        'walk_range_min': _walkMin,
        'walk_range_max': _walkMax,
        'bike_range_min': _bikeMin,
        'bike_range_max': _bikeMax,
        'default_activity': _defaultActivity,
        'selected_avatar': avatarToSave,
        'daily_steps_goal': _dailyStepsGoal,
        'updated_at': FieldValue.serverTimestamp(),
      };

      // 1. Save locally in SharedPreferences first for instant responsiveness
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_avatar', avatarToSave);
      await prefs.setString('gender', _gender);
      await prefs.setDouble('walk_range_min', _walkMin);
      await prefs.setDouble('walk_range_max', _walkMax);
      await prefs.setDouble('bike_range_min', _bikeMin);
      await prefs.setDouble('bike_range_max', _bikeMax);
      await prefs.setString('default_activity', _defaultActivity);
      await prefs.setString('birth_date', _birthDate!.toIso8601String());
      await prefs.setInt('daily_steps_goal', _dailyStepsGoal);

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
      
      final userName = await AuthService().getUserName() ?? enteredUsername;

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

  void _nextStep() {
    if (_currentStep == 0) {
      if (_firstNameController.text.trim().isEmpty || 
          _lastNameController.text.trim().isEmpty || 
          _usernameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prosím vyplňte všechna textová pole.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      if (_birthDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prosím zvolte své datum narození.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }
    
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    } else {
      _saveProfile();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF263238),
      appBar: AppBar(
        title: const Text(
          'Nastavení Profilu',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E272C),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            tooltip: 'Odhlásit se',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF37474F),
                  title: const Text('Odhlásit se?', style: TextStyle(color: Colors.white)),
                  content: const Text(
                    'Opravdu se chcete odhlásit a vrátit na přihlašovací obrazovku?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      child: const Text('Odhlásit se'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                const storage = FlutterSecureStorage();
                await storage.deleteAll();
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Stepper Indicator
            _buildStepperProgress(),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.05, 0.0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildStepContent(),
                ),
              ),
            ),
            
            // Bottom Action Buttons
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperProgress() {
    return Container(
      color: const Color(0xFF1E272C),
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepDot(0, 'Osobní', Icons.person),
          _buildStepDivider(0),
          _buildStepDot(1, 'Hrdina', Icons.face),
          _buildStepDivider(1),
          _buildStepDot(2, 'Cíle', Icons.sports_score),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label, IconData icon) {
    final isCompleted = _currentStep > step;
    final isActive = _currentStep == step;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive 
                ? const Color(0xFFBFFF00)
                : isCompleted 
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF37474F),
            border: Border.all(
              color: isActive 
                  ? const Color(0xFFBFFF00)
                  : isCompleted 
                      ? const Color(0xFF1B5E20)
                      : Colors.white24,
              width: 2,
            ),
            boxShadow: isActive 
                ? [
                    BoxShadow(
                      color: const Color(0xFFBFFF00).withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isActive 
                ? Colors.black 
                : isCompleted 
                    ? Colors.white 
                    : Colors.white54,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive 
                ? const Color(0xFFBFFF00) 
                : isCompleted 
                    ? Colors.white70 
                    : Colors.white38,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        )
      ],
    );
  }

  Widget _buildStepDivider(int afterStep) {
    final isPassed = _currentStep > afterStep;
    return Container(
      width: 40,
      height: 3,
      margin: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
      decoration: BoxDecoration(
        color: isPassed ? const Color(0xFF1B5E20) : const Color(0xFF37474F),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildAvatarStep();
      case 2:
      default:
        return _buildGoalsStep();
    }
  }

  Widget _buildPersonalStep() {
    final ageText = _birthDate == null 
        ? 'Nevybráno' 
        : '${_birthDate!.day}. ${_birthDate!.month}. ${_birthDate!.year} (${_calculateAge(_birthDate!)} let)';

    return Column(
      key: const ValueKey('personal_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: AppLogo(size: 90),
        ),
        const SizedBox(height: 16),
        const Text(
          'Osobní údaje',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Představ se nám, abychom mohli přizpůsobit zážitky z chůze na míru tvému věku.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        _buildSectionTextField(
          controller: _firstNameController,
          labelText: 'Jméno',
          prefixIcon: Icons.badge_outlined,
        ),
        _buildSectionTextField(
          controller: _lastNameController,
          labelText: 'Příjmení',
          prefixIcon: Icons.badge_outlined,
        ),
        _buildSectionTextField(
          controller: _usernameController,
          labelText: 'Herní přezdívka',
          prefixIcon: Icons.sports_esports_outlined,
        ),
        const SizedBox(height: 16),

        // Birthdate Picker Box
        GestureDetector(
          onTap: _selectBirthDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E272C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _birthDate != null ? const Color(0xFFBFFF00).withOpacity(0.5) : Colors.white12,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF263238),
                  child: Icon(Icons.cake, color: Color(0xFFBFFF00)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Datum narození',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ageText,
                        style: TextStyle(
                          color: _birthDate == null ? Colors.white38 : const Color(0xFFBFFF00),
                          fontSize: 13,
                          fontWeight: _birthDate == null ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_month, color: Colors.white54),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Gender selection
        const Text(
          'Pohlaví',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildGenderButton(
                type: 'male',
                label: _birthDate != null && _calculateAge(_birthDate!) < 18 ? 'Chlapec' : 'Muž',
                icon: Icons.male,
                isSelected: _gender == 'male',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildGenderButton(
                type: 'female',
                label: _birthDate != null && _calculateAge(_birthDate!) < 18 ? 'Dívka' : 'Žena',
                icon: Icons.female,
                isSelected: _gender == 'female',
              ),
            ),
          ],
        ),

        // Adult Male Style choice (if age >= 18 and gender == 'male')
        if (_birthDate != null && _calculateAge(_birthDate!) >= 18 && _gender == 'male') ...[
          const SizedBox(height: 16),
          const Text(
            'Styl postavy na mapě',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Mladší muž')),
                  selected: _adultMaleOption == 'man',
                  selectedColor: const Color(0xFFBFFF00),
                  backgroundColor: const Color(0xFF1E272C),
                  labelStyle: TextStyle(
                    color: _adultMaleOption == 'man' ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _adultMaleOption = 'man';
                      });
                      _updateAssignedAvatar();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Starší chlap')),
                  selected: _adultMaleOption == 'chlap',
                  selectedColor: const Color(0xFFBFFF00),
                  backgroundColor: const Color(0xFF1E272C),
                  labelStyle: TextStyle(
                    color: _adultMaleOption == 'chlap' ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _adultMaleOption = 'chlap';
                      });
                      _updateAssignedAvatar();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarStep() {
    return Column(
      key: const ValueKey('avatar_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Vyber si svého hrdinu',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Zvol si fotku z galerie, nebo použij našeho tématického avatara na základě tvého profilu.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),

        // Circular custom avatar picker with Neon Lime rim
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E272C),
                    border: Border.all(
                      color: _selectedAvatarBase64 != null ? const Color(0xFFBFFF00) : Colors.white24,
                      width: 4,
                    ),
                    boxShadow: _selectedAvatarBase64 != null
                        ? [
                            BoxShadow(
                              color: const Color(0xFFBFFF00).withOpacity(0.2),
                              blurRadius: 15,
                              spreadRadius: 3,
                            )
                          ]
                        : [],
                  ),
                  child: ClipOval(
                    child: _customImageFile != null
                        ? Image.file(_customImageFile!, fit: BoxFit.cover)
                        : _selectedAvatarBase64 != null
                            ? const Center(child: Icon(Icons.person, color: Colors.white, size: 70))
                            : Container(
                                color: const Color(0xFF1E272C),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, color: Color(0xFFBFFF00), size: 36),
                                    SizedBox(height: 8),
                                    Text(
                                      'Vlastní fotka',
                                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 42,
                  width: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFBFFF00),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 2)),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Default Hero Preview Card
        const Text(
          'Předdefinovaný hrdina',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        
        _buildPresetAvatarCard(),
      ],
    );
  }

  Widget _buildPresetAvatarCard() {
    final String currentId = _presetAvatarId ?? (_gender == 'male' ? 'boy' : 'girl');
    final bool isPresetSelected = _selectedAvatarBase64 == null;

    String avatarLabel = 'Hrdina';
    switch (currentId) {
      case 'boy':
        avatarLabel = 'Mladý dobrodruh (Chlapec)';
        break;
      case 'girl':
        avatarLabel = 'Mladá běžkyně (Dívka)';
        break;
      case 'man':
        avatarLabel = 'Mladší běžec (Muž)';
        break;
      case 'chlap':
        avatarLabel = 'Zkušený chodec (Chlap)';
        break;
      case 'woman':
        avatarLabel = 'Odhodlaná sportovkyně (Žena)';
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAvatarBase64 = null;
          _customImageFile = null;
        });
        _updateAssignedAvatar();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E272C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isPresetSelected ? const Color(0xFFBFFF00) : Colors.white12,
            width: 2,
          ),
          boxShadow: isPresetSelected
              ? [BoxShadow(color: const Color(0xFFBFFF00).withOpacity(0.15), blurRadius: 10)]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF263238),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/$currentId.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        _gender == 'male' ? '👦' : '👧',
                        style: const TextStyle(fontSize: 40),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avatarLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Profilová postava automaticky vygenerovaná podle tvého pohlaví a věku.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isPresetSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFBFFF00),
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalsStep() {
    return Column(
      key: const ValueKey('goals_step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Nastavení aktivit a cílů',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Zvol si výchozí aktivitu a upřesni své limity pro trasy generované naší AI.',
          style: TextStyle(fontSize: 13, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Default Activity Toggle
        const Text(
          'Výchozí typ aktivity',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

        // Kilometer Ranges
        const Text(
          'Preferovaný rozsah tras',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),

        // Walk Range Slider
        _buildSliderCard(
          title: 'Pěší okruhy (Chůze)',
          subtitle: 'Nastavte minimální a maximální délku tras',
          minVal: _walkMin,
          maxVal: _walkMax,
          rangeMin: 5.0,
          rangeMax: 30.0,
          activeColor: const Color(0xFF1B5E20),
          onMinChanged: (v) => setState(() => _walkMin = v),
          onMaxChanged: (v) => setState(() => _walkMax = v),
        ),

        const SizedBox(height: 16),

        // Bike Range Slider
        _buildSliderCard(
          title: 'Cyklo okruhy (Kolo)',
          subtitle: 'Nastavte minimální a maximální délku vyjížděk',
          minVal: _bikeMin,
          maxVal: _bikeMax,
          rangeMin: 20.0,
          rangeMax: 50.0,
          activeColor: const Color(0xFFBFFF00),
          onMinChanged: (v) => setState(() => _bikeMin = v),
          onMaxChanged: (v) => setState(() => _bikeMax = v),
        ),

        const SizedBox(height: 24),

        // Daily Steps Goal Card
        Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E272C),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎯 Denní cíl kroků',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    '${_dailyStepsGoal.toString().replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]} ")}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFBFFF00)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Nastavte si počet kroků, které chcete denně ujít.',
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFFBFFF00),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFFBFFF00),
                  overlayColor: const Color(0xFFBFFF00).withOpacity(0.2),
                  valueIndicatorColor: const Color(0xFF1E272C),
                  valueIndicatorTextStyle: const TextStyle(color: Color(0xFFBFFF00), fontWeight: FontWeight.bold),
                ),
                child: Slider(
                  value: _dailyStepsGoal.toDouble(),
                  min: 1000.0,
                  max: 30000.0,
                  divisions: 29,
                  label: '$_dailyStepsGoal',
                  onChanged: (v) {
                    setState(() {
                      _dailyStepsGoal = v.toInt();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBottomBar() {
    final bool isFirstStep = _currentStep == 0;
    
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1E272C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          if (!isFirstStep) ...[
            Expanded(
              flex: 1,
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Zpět', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFFF00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        _currentStep == 2 ? 'Uložit a Vstoupit' : 'Pokračovat',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 15, color: Colors.white),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFFBFFF00), size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white12, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.white12, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFBFFF00), width: 2),
          ),
          filled: true,
          fillColor: const Color(0xFF1E272C),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildGenderButton({
    required String type,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = type;
        });
        _updateAssignedAvatar();
      },
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBFFF00).withOpacity(0.15) : const Color(0xFF1E272C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFBFFF00) : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFBFFF00) : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFBFFF00) : Colors.white70,
              ),
            ),
          ],
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
          color: isSelected ? const Color(0xFFBFFF00).withOpacity(0.15) : const Color(0xFF1E272C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFBFFF00) : Colors.white12,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFBFFF00) : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFFBFFF00) : Colors.white70,
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
    required Color activeColor,
    required ValueChanged<double> onMinChanged,
    required ValueChanged<double> onMaxChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E272C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white54)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min: ${minVal.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFBFFF00)),
              ),
              Text(
                'Max: ${maxVal.toStringAsFixed(0)} km',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFBFFF00)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: Colors.white10,
              thumbColor: activeColor,
              overlayColor: activeColor.withOpacity(0.2),
              valueIndicatorColor: const Color(0xFF1E272C),
              valueIndicatorTextStyle: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
            ),
            child: Column(
              children: [
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
        ],
      ),
    );
  }
}
