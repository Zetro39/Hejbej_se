import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../profile/profile_creation_screen.dart';

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
      'updated_at': FieldValue.serverTimestamp(),
    };
    
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
            color: Colors.black.withOpacity(0.03),
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
          prefixIcon: Icon(prefixIcon, color: Colors.lightBlue.shade300, size: 22),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.lightBlue, width: 2),
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'REGISTRACE ÚČTU',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
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
                  const SizedBox(height: 8),
                  Text(
                    'Vytvoř si účet',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
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
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
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
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    validator: (v) {
                      if (v != _password.text) return 'Hesla se neshodují';
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 8),
                  Text(
                    'Způsob ověření účtu',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
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
                          selectedColor: Colors.lightBlue.shade100,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: !_useSmsVerification ? Colors.lightBlue.shade800 : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: !_useSmsVerification ? Colors.lightBlue : Colors.grey.shade300),
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
                          selectedColor: Colors.lightBlue.shade100,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: _useSmsVerification ? Colors.lightBlue.shade800 : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _useSmsVerification ? Colors.lightBlue : Colors.grey.shade300),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_useSmsVerification) ...[
                    _buildTextField(
                      controller: _phone,
                      labelText: 'Telefonní číslo (např. +420 777 123 456)',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (_useSmsVerification) {
                          if (v == null || v.trim().isEmpty) return 'Vyplňte telefonní číslo';
                          final clean = v.trim().replaceAll(' ', '');
                          if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(clean)) {
                            return 'Neplatný formát. Použijte např. +420 777 123 456';
                          }
                        }
                        return null;
                      },
                    ),
                  ],

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 24, thickness: 1),
                  ),

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
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
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
                        child: CircularProgressIndicator(color: Colors.lightBlue),
                      ),
                    )
                  else
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lime,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shadowColor: Colors.lime.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Registrovat se',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
    );
  }
}
