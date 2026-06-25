import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../profile/profile_creation_screen.dart';
import '../../widgets/app_logo.dart';
import '../../main_shell.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  
  bool _useSmsVerification = false;
  String _verificationId = '';
  bool _isSubmitting = false;
  String? _error;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedTheme = 'grey';
  String? _selectedKraj;
  String? _selectedGender;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _phone.dispose();
    super.dispose();
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

  Future<void> _finalizeRegistration(User user) async {
    final username = _username.text.trim();
    final friendCode = '#${username.toUpperCase()}${(100 + DateTime.now().millisecondsSinceEpoch % 900)}';
    
    final profile = {
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'username': username,
      'username_clean': _cleanStringForSearch(username),
      'friend_code': friendCode,
      'friend_code_clean': _cleanStringForSearch(friendCode),
      'phone_number': _useSmsVerification ? _phone.text.trim().replaceAll(' ', '') : null,
      'design_theme': _selectedTheme,
      'kraj': _selectedKraj,
      'gender': _selectedGender,
      'updated_at': FieldValue.serverTimestamp(),
    };
    
    try {
      if (_selectedGender != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('gender', _selectedGender!);
      }
    } catch (_) {}
    
    try {
      await AuthService().saveProfile(user.uid, profile)
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Failed to save profile basics to Firestore: $e');
    }
        
    try {
      await AuthService().saveUserName(username)
          .timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Failed to save username to local storage: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('design_theme', _selectedTheme);
      MainShell.themeNotifier.value = _selectedTheme;
    } catch (e) {
      debugPrint('Failed to save theme to SharedPreferences: $e');
    }
  }

  Future<void> _startPhoneVerification(User user, String phoneNumber) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService().verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await user.linkWithCredential(credential);
          await _finalizeRegistration(user);
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileCreationScreen()));
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _error = 'Ověření telefonu selhalo: ${e.code == 'invalid-phone-number' ? 'Neplatné telefonní číslo.' : (e.message ?? e.code)}';
            _isSubmitting = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isSubmitting = false;
          });
          _showOtpDialog(user);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _error = 'Chyba při inicializaci SMS: $e';
        _isSubmitting = false;
      });
    }
  }

  void _showOtpDialog(User user) {
    final otpController = TextEditingController();
    bool isVerifyingOtp = false;
    String? otpError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('✉️ Ověření přes SMS', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Zadejte 6místný kód zaslaný na číslo\n${_phone.text.trim()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
                      ),
                    ),
                  ),
                  if (otpError != null) ...[
                    const SizedBox(height: 12),
                    Text(otpError!, style: const TextStyle(color: Colors.red, fontSize: 13), textAlign: TextAlign.center),
                  ],
                  if (isVerifyingOtp) ...[
                    const SizedBox(height: 20),
                    const Center(child: CircularProgressIndicator(color: Colors.lightBlue)),
                  ],
                ],
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isVerifyingOtp
                            ? null
                            : () {
                                Navigator.pop(context);
                                FirebaseAuth.instance.signOut();
                              },
                        child: const Text('Zrušit', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isVerifyingOtp
                            ? null
                            : () async {
                                final code = otpController.text.trim();
                                if (code.length != 6) {
                                  setDialogState(() {
                                    otpError = 'Zadejte platný 6místný kód';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isVerifyingOtp = true;
                                  otpError = null;
                                });

                                try {
                                  await AuthService().linkPhoneNumber(_verificationId, code);
                                  await _finalizeRegistration(user);
                                  
                                  if (!mounted) return;
                                  Navigator.pop(context); // Pop dialog
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => const ProfileCreationScreen()),
                                  );
                                } catch (e) {
                                  setDialogState(() {
                                    isVerifyingOtp = false;
                                    otpError = 'Neplatný kód: ${e.toString().replaceAll('Exception: ', '').replaceAll('FirebaseAuthException: ', '')}';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lime,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Ověřit', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedKraj == null) {
      setState(() {
        _error = 'Vyberte prosím svůj kraj.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final password = _password.text;
      
      final cred = await AuthService().registerWithEmail(email, password)
          .timeout(const Duration(seconds: 12), onTimeout: () => throw TimeoutException('Registrace účtu vypršela. Zkontrolujte připojení k internetu.'));
      
      final user = cred.user;
      if (user == null) throw Exception('Registrace selhala');

      if (_useSmsVerification) {
        final cleanPhone = _phone.text.trim().replaceAll(' ', '');
        await _startPhoneVerification(user, cleanPhone);
      } else {
        await _finalizeRegistration(user);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ProfileCreationScreen()));
      }
    } on TimeoutException catch (e) {
      setState(() {
        _error = e.message;
        _isSubmitting = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.code == 'weak-password'
            ? 'Heslo je příliš krátké.'
            : e.code == 'email-already-in-use'
                ? 'Tento e-mail je již registrován.'
                : (e.message ?? e.code);
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isSubmitting = false;
      });
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          prefixIcon: Icon(prefixIcon, color: const Color(0xFF5C9E00), size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFBFFF00), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.redAccent, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      appBar: AppBar(
        title: const Text(
          'Vytvořit účet',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF263238),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFFF00).withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AppLogo(size: 80)),
                      const SizedBox(height: 20),
                      const Text(
                        'Hejbej se s námi!',
                        style: TextStyle(
                          color: Color(0xFF263238),
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Připoj se a začni sledovat své trasy, odemykat společníky a sbírat limetky.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Přihlašovací údaje',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _email,
                              labelText: 'E-mail',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Vyplňte e-mail';
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                  return 'Neplatný formát e-mailu';
                                }
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _password,
                              labelText: 'Heslo',
                              prefixIcon: Icons.lock_outlined,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if (v == null || v.length < 6) return 'Heslo musí mít alespoň 6 znaků';
                                return null;
                              },
                            ),
                            _buildTextField(
                              controller: _confirm,
                              labelText: 'Potvrdit heslo',
                              prefixIcon: Icons.lock_reset_outlined,
                              obscureText: _obscureConfirm,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                              validator: (v) {
                                if (v != _password.text) return 'Hesla se neshodují';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Způsob ověření účtu',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Přes E-mail')),
                                    selected: !_useSmsVerification,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _useSmsVerification = false;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFBFFF00).withOpacity(0.25),
                                    backgroundColor: Colors.grey.shade50,
                                    labelStyle: TextStyle(
                                      color: !_useSmsVerification ? const Color(0xFF1B5E20) : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: !_useSmsVerification ? const Color(0xFFBFFF00) : Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Center(child: Text('Přes SMS (číslo)')),
                                    selected: _useSmsVerification,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _useSmsVerification = true;
                                        });
                                      }
                                    },
                                    selectedColor: const Color(0xFFBFFF00).withOpacity(0.25),
                                    backgroundColor: Colors.grey.shade50,
                                    labelStyle: TextStyle(
                                      color: _useSmsVerification ? const Color(0xFF1B5E20) : Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: _useSmsVerification ? const Color(0xFFBFFF00) : Colors.grey.shade200,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_useSmsVerification) ...[
                              _buildTextField(
                                controller: _phone,
                                labelText: 'Telefonní číslo',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                validator: (v) {
                                  if (_useSmsVerification) {
                                    if (v == null || v.trim().isEmpty) return 'Vyplňte telefonní číslo';
                                    final clean = v.trim().replaceAll(' ', '');
                                    if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(clean)) {
                                      return 'Neplatný formát (např. +420777123456)';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(height: 24, thickness: 1, color: Color(0xFFF1F1F1)),
                            ),
                            const Text(
                              'Osobní údaje',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _firstName,
                              labelText: 'Jméno',
                              prefixIcon: Icons.badge_outlined,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte jméno' : null,
                            ),
                            _buildTextField(
                              controller: _lastName,
                              labelText: 'Příjmení',
                              prefixIcon: Icons.badge_outlined,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vyplňte příjmení' : null,
                            ),
                            _buildTextField(
                              controller: _username,
                              labelText: 'Herní přezdívka',
                              prefixIcon: Icons.sports_esports_outlined,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Vyplňte přezdívku';
                                if (v.trim().length < 3) return 'Přezdívka musí mít alespoň 3 znaky';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: InputDecoration(
                                labelText: 'Pohlaví (nepovinné)',
                                labelStyle: const TextStyle(color: Colors.black54),
                                prefixIcon: const Icon(Icons.face_outlined, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFBFFF00), width: 2),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Muž')),
                                DropdownMenuItem(value: 'female', child: Text('Žena')),
                                DropdownMenuItem(value: 'other', child: Text('Neuvedeno')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedGender = (val == 'other' ? null : val);
                                });
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(height: 24, thickness: 1, color: Color(0xFFF1F1F1)),
                            ),
                            const Text(
                              'Region (Kraj) v ČR',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _selectedKraj,
                              decoration: InputDecoration(
                                labelText: 'Vyberte svůj domovský kraj',
                                labelStyle: const TextStyle(color: Colors.black54),
                                prefixIcon: const Icon(Icons.map_outlined, color: Colors.grey),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Color(0xFFBFFF00), width: 2),
                                ),
                              ),
                              validator: (v) => v == null ? 'Vyberte prosím svůj kraj' : null,
                              items: const [
                                DropdownMenuItem(value: 'Praha', child: Text('Hlavní město Praha')),
                                DropdownMenuItem(value: 'Středočeský', child: Text('Středočeský kraj')),
                                DropdownMenuItem(value: 'Jihočeský', child: Text('Jihočeský kraj')),
                                DropdownMenuItem(value: 'Plzeňský', child: Text('Plzeňský kraj')),
                                DropdownMenuItem(value: 'Karlovarský', child: Text('Karlovarský kraj')),
                                DropdownMenuItem(value: 'Ústecký', child: Text('Ústecký kraj')),
                                DropdownMenuItem(value: 'Liberecký', child: Text('Liberecký kraj')),
                                DropdownMenuItem(value: 'Královéhradecký', child: Text('Královéhradecký kraj')),
                                DropdownMenuItem(value: 'Pardubický', child: Text('Pardubický kraj')),
                                DropdownMenuItem(value: 'Vysočina', child: Text('Kraj Vysočina')),
                                DropdownMenuItem(value: 'Jihomoravský', child: Text('Jihomoravský kraj')),
                                DropdownMenuItem(value: 'Olomoucký', child: Text('Olomoucký kraj')),
                                DropdownMenuItem(value: 'Zlínský', child: Text('Zlínský kraj')),
                                DropdownMenuItem(value: 'Moravskoslezský', child: Text('Moravskoslezský kraj')),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedKraj = val;
                                });
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Divider(height: 24, thickness: 1, color: Color(0xFFF1F1F1)),
                            ),
                            const Text(
                              'Vzhled aplikace',
                              style: TextStyle(
                                color: Color(0xFF263238),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTheme = 'grey';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF263238),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _selectedTheme == 'grey' ? const Color(0xFFBFFF00) : Colors.transparent,
                                          width: 2.5,
                                        ),
                                        boxShadow: _selectedTheme == 'grey'
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFBFFF00).withOpacity(0.2),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Column(
                                        children: const [
                                          Icon(Icons.dark_mode_rounded, color: Colors.white, size: 28),
                                          SizedBox(height: 8),
                                          Text(
                                            'Prémiová Šedá',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedTheme = 'white';
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9FBFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _selectedTheme == 'white' ? const Color(0xFFBFFF00) : Colors.grey.shade300,
                                          width: 2.5,
                                        ),
                                        boxShadow: _selectedTheme == 'white'
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFBFFF00).withOpacity(0.2),
                                                  blurRadius: 10,
                                                  spreadRadius: 1,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(Icons.light_mode_rounded, color: Colors.amber.shade700, size: 28),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Prémiová Bílá',
                                            style: TextStyle(
                                              color: Color(0xFF263238),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade100),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: Colors.red, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (_isSubmitting)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(color: Color(0xFF5C9E00)),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFBFFF00).withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFD4FF00),
                                Color(0xFFBFFF00),
                              ],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Registrovat se',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
