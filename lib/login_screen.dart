import 'dart:io';
import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import 'main_shell.dart';
import 'services/auth_service.dart';
import 'features/profile/distance_preference_setup_screen.dart';
import 'features/auth/registration_screen.dart';
import 'features/profile/profile_creation_screen.dart';
import 'widgets/app_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorText;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleUserRouting(String name) async {
    await AuthService().saveUserName(name);
    await AuthService().syncFirestoreToLocal();
    if (!mounted) return;
    
    final hasProfile = await AuthService().isProfileCompleted();
    if (!mounted) return;
    
    if (hasProfile) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => MainShell(userName: name)),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ProfileCreationScreen()),
      );
    }
  }

  void _onLoginPressed() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Vyplňte e-mail a heslo';
      });
      return;
    }

    AuthService().signInWithEmail(email, password).then((cred) async {
      final user = cred.user;
      if (user != null) {
        String name = user.email ?? '';
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (doc.exists && doc.data()?['username'] != null) {
            name = doc.data()?['username'] as String;
          }
        } catch (_) {}
        await _handleUserRouting(name);
      }
    }).catchError((e) {
      if (!mounted) return;
      String message = 'Přihlášení selhalo.';
      try {
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'user-not-found':
              message = 'Tento e-mail u nás není registrovaný.';
              break;
            case 'wrong-password':
              message = 'Zadané heslo není správné.';
              break;
            case 'invalid-email':
              message = 'Neplatný formát e-mailu.';
              break;
            case 'user-disabled':
              message = 'Účet byl zablokován.';
              break;
            default:
              message = 'Přihlášení selhalo: ${e.message ?? e.code}';
          }
        } else {
          message = e.toString();
        }
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });
  }

  void _onRegisterPressed() async {
    // Open comprehensive registration form
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegistrationScreen()));
  }

  Future<void> _signInWithGoogle() async {
    try {
      final google = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await google.signIn();
      if (account == null) return; // user canceled
      final auth = await account.authentication;
      
      // Sign in to Firebase Auth!
      final cred = await AuthService().signInWithGoogle(auth.accessToken ?? '', auth.idToken);
      final user = cred.user;
      final name = user?.displayName ?? user?.email ?? 'Uživatel';

      await AuthService().saveAuthCredentials('google', {
        'accessToken': auth.accessToken,
        'idToken': auth.idToken,
        'email': account.email,
      });
      await _handleUserRouting(name);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Přihlášení přes Google selhalo')));
    }
  }

  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final shaNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: shaNonce,
      );

      final cred = await AuthService().signInWithApple(
        idToken: credential.identityToken ?? '',
        rawNonce: rawNonce,
      );
      final user = cred.user;
      final name = user?.displayName ?? user?.email ?? 'Uživatel';

      await AuthService().saveAuthCredentials('apple', {
        'identityToken': credential.identityToken,
        'email': credential.email,
      });
      await _handleUserRouting(name);
    } catch (e) {
      debugPrint('Apple sign-in failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Přihlášení přes Apple selhalo')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBFC),
      body: Stack(
        children: [
          // Background soft glowing gradients
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F5E9).withOpacity(0.5),
              ),
            ),
          ),
          Positioned(
            top: -50,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFBFFF00).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE1F5FE).withOpacity(0.4),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 64,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    // Elegant Premium Logo
                    Center(
                      child: Column(
                        children: [
                          const AppLogo(size: 110),
                          const SizedBox(height: 20),
                          const Text(
                            'Hejbej se',
                            style: TextStyle(
                              color: Color(0xFF263238),
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Pohyb, který tě baví',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 50),
                    
                    // Input Card with slight Glassmorphism feel
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'E-mail',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              errorText: _errorText,
                              prefixIcon: const Icon(Icons.email_outlined, size: 22),
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
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              if (_errorText != null) {
                                setState(() {
                                  _errorText = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Heslo',
                              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 22),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: Colors.grey.shade600,
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
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
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 28),
                          
                          // Email/password sign-in button
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
                              onPressed: _onLoginPressed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Přihlásit se',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1B5E20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Social Sign-in section
                    Center(
                      child: Text(
                        'Nebo se přihlásit přes',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          child: CustomPaint(
                            size: const Size(22, 22),
                            painter: const GoogleLogoPainter(),
                          ),
                          onTap: _signInWithGoogle,
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          child: const Icon(
                            Icons.apple,
                            size: 26,
                            color: Colors.black,
                          ),
                          onTap: _signInWithApple,
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          child: const Icon(
                            Icons.facebook_rounded,
                            size: 26,
                            color: Color(0xFF1877F2),
                          ),
                          onTap: _showSocialLoginNotice,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(height: 20),
                    
                    // Register button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Ještě nemáš účet?',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 15,
                          ),
                        ),
                        TextButton(
                          onPressed: _onRegisterPressed,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Registrovat se',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5C9E00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSocialLoginNotice() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Přihlášení'),
        content: const Text(
          'Tato možnost přihlášení bude brzy dostupná. Nyní prosím použijte přihlášení přes E-mail a Heslo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Rozumím'),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class GoogleLogoPainter extends CustomPainter {
  const GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double r = width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.24
      ..strokeCap = StrokeCap.butt;

    final center = Offset(r, r);
    final rect = Rect.fromCircle(center: center, radius: r - paint.strokeWidth / 2);

    // Red sector
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.5, 1.4, false, paint);

    // Yellow sector
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -1.1, 1.1, false, paint);

    // Green sector
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.0, 1.9, false, paint);

    // Blue sector
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 1.9, 1.8, false, paint);

    // Blue bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTRB(r, r - paint.strokeWidth / 2, r + r, r + paint.strokeWidth / 2),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}